package backup

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"math"
)

const (
	// File format v1:
	//   header: magic | version | chunk size | 96-bit random nonce seed
	//   record: index | plaintext length | ciphertext length | AES-GCM data
	//   final:  record with zero plaintext and an authenticated empty payload
	// Header and record identity are authenticated as additional data.
	formatVersion    = 1
	magic            = "MLMDBK01"
	chunkSize        = 1 << 20
	noncePrefixSize  = 12
	gcmNonceSize     = 12
	tagSize          = 16
	headerSize       = len(magic) + 1 + 4 + noncePrefixSize
	recordHeaderSize = 4 + 4 + 4
)

var (
	ErrInvalidKey   = errors.New("invalid backup key")
	ErrInvalidData  = errors.New("invalid backup data")
	ErrUnsupported  = errors.New("unsupported backup format")
	ErrDataTooLarge = errors.New("backup data exceeds format limit")
)

type Cipher struct {
	gcm cipher.AEAD
}

func New(key []byte) (*Cipher, error) {
	if len(key) != 32 {
		return nil, ErrInvalidKey
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("create aes-256 cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("create gcm: %w", err)
	}
	if gcm.NonceSize() != gcmNonceSize {
		return nil, fmt.Errorf("unexpected gcm nonce size: %d", gcm.NonceSize())
	}
	return &Cipher{gcm: gcm}, nil
}

func Encrypt(ctx context.Context, dst io.Writer, src io.Reader, key []byte) error {
	c, err := New(key)
	if err != nil {
		return err
	}
	return c.Encrypt(ctx, dst, src)
}

func Decrypt(ctx context.Context, dst io.Writer, src io.Reader, key []byte) error {
	c, err := New(key)
	if err != nil {
		return err
	}
	return c.Decrypt(ctx, dst, src)
}

func (c *Cipher) Encrypt(ctx context.Context, dst io.Writer, src io.Reader) error {
	var prefix [noncePrefixSize]byte
	if _, err := io.ReadFull(rand.Reader, prefix[:]); err != nil {
		return fmt.Errorf("generate nonce prefix: %w", err)
	}
	header := make([]byte, headerSize)
	copy(header, []byte(magic))
	header[len(magic)] = formatVersion
	binary.BigEndian.PutUint32(header[len(magic)+1:], chunkSize)
	copy(header[len(magic)+1+4:], prefix[:])
	if err := writeAll(dst, header); err != nil {
		return err
	}

	buf := make([]byte, chunkSize)
	var index uint32
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		n, readErr := src.Read(buf)
		if n > 0 {
			if index == math.MaxUint32 {
				return ErrDataTooLarge
			}
			if err := c.writeChunk(dst, header, prefix, index, buf[:n]); err != nil {
				return err
			}
			index++
		}
		if readErr == nil {
			if n < len(buf) {
				return c.writeFinal(dst, header, prefix, index)
			}
			continue
		}
		if errors.Is(readErr, io.EOF) || errors.Is(readErr, io.ErrUnexpectedEOF) {
			return c.writeFinal(dst, header, prefix, index)
		}
		if n > 0 {
			return readErr
		}
		if readErr != nil {
			return readErr
		}
	}
}

func (c *Cipher) Decrypt(ctx context.Context, dst io.Writer, src io.Reader) error {
	header, err := readExact(src, headerSize)
	if err != nil {
		return err
	}
	if string(header[:len(magic)]) != magic {
		return ErrUnsupported
	}
	if header[len(magic)] != formatVersion {
		return ErrUnsupported
	}
	if binary.BigEndian.Uint32(header[len(magic)+1:]) != chunkSize {
		return ErrUnsupported
	}

	var prefix [noncePrefixSize]byte
	copy(prefix[:], header[len(magic)+1+4:])

	for index := uint32(0); ; index++ {
		if err := ctx.Err(); err != nil {
			return err
		}
		recordHeader, err := readExact(src, recordHeaderSize)
		if err != nil {
			return err
		}
		recordIndex := binary.BigEndian.Uint32(recordHeader[0:4])
		plainLen := binary.BigEndian.Uint32(recordHeader[4:8])
		cipherLen := binary.BigEndian.Uint32(recordHeader[8:12])
		if recordIndex != index || plainLen > chunkSize {
			return ErrInvalidData
		}
		if plainLen == 0 && cipherLen == tagSize {
			return c.verifyFinal(src, header, prefix, index, recordHeader)
		}
		if cipherLen != plainLen+tagSize {
			return ErrInvalidData
		}
		payload, err := readExact(src, int(cipherLen))
		if err != nil {
			return err
		}
		nonce := makeNonce(prefix, index)
		aad := makeAAD(header, index, plainLen, false)
		plain, err := c.gcm.Open(nil, nonce[:], payload, aad)
		if err != nil || uint32(len(plain)) != plainLen {
			return ErrInvalidData
		}
		if err := writeAll(dst, plain); err != nil {
			return err
		}
		if plainLen == chunkSize {
			if index == math.MaxUint32 {
				return ErrInvalidData
			}
			continue
		}
		return c.readFinal(src, header, prefix, index+1)
	}
}

func (c *Cipher) verifyFinal(src io.Reader, header []byte, prefix [noncePrefixSize]byte, index uint32, recordHeader []byte) error {
	finalCipherLen := binary.BigEndian.Uint32(recordHeader[8:12])
	finalPayload, err := readExact(src, int(finalCipherLen))
	if err != nil {
		return err
	}
	finalNonce := makeNonce(prefix, index)
	finalAAD := makeAAD(header, index, 0, true)
	if _, err := c.gcm.Open(nil, finalNonce[:], finalPayload, finalAAD); err != nil {
		return ErrInvalidData
	}
	tail := make([]byte, 1)
	n, err := src.Read(tail)
	if n > 0 || err == nil {
		return ErrInvalidData
	}
	if errors.Is(err, io.EOF) {
		return nil
	}
	return err
}

func (c *Cipher) readFinal(src io.Reader, header []byte, prefix [noncePrefixSize]byte, index uint32) error {
	finalHeader, err := readExact(src, recordHeaderSize)
	if err != nil {
		return err
	}
	finalIndex := binary.BigEndian.Uint32(finalHeader[0:4])
	finalPlainLen := binary.BigEndian.Uint32(finalHeader[4:8])
	finalCipherLen := binary.BigEndian.Uint32(finalHeader[8:12])
	if finalIndex != index || finalPlainLen != 0 || finalCipherLen != tagSize {
		return ErrInvalidData
	}
	finalPayload, err := readExact(src, int(finalCipherLen))
	if err != nil {
		return err
	}
	finalNonce := makeNonce(prefix, finalIndex)
	finalAAD := makeAAD(header, finalIndex, 0, true)
	if _, err := c.gcm.Open(nil, finalNonce[:], finalPayload, finalAAD); err != nil {
		return ErrInvalidData
	}
	tail := make([]byte, 1)
	n, err := src.Read(tail)
	if n > 0 || err == nil {
		return ErrInvalidData
	}
	if errors.Is(err, io.EOF) {
		return nil
	}
	return err
}

func (c *Cipher) writeChunk(dst io.Writer, header []byte, prefix [noncePrefixSize]byte, index uint32, plain []byte) error {
	nonce := makeNonce(prefix, index)
	aad := makeAAD(header, index, uint32(len(plain)), false)
	ciphertext := c.gcm.Seal(nil, nonce[:], plain, aad)
	return writeRecord(dst, index, uint32(len(plain)), uint32(len(ciphertext)), ciphertext)
}

func (c *Cipher) writeFinal(dst io.Writer, header []byte, prefix [noncePrefixSize]byte, index uint32) error {
	nonce := makeNonce(prefix, index)
	aad := makeAAD(header, index, 0, true)
	ciphertext := c.gcm.Seal(nil, nonce[:], nil, aad)
	return writeRecord(dst, index, 0, uint32(len(ciphertext)), ciphertext)
}

func writeRecord(dst io.Writer, index, plainLen, cipherLen uint32, ciphertext []byte) error {
	var header [recordHeaderSize]byte
	binary.BigEndian.PutUint32(header[0:4], index)
	binary.BigEndian.PutUint32(header[4:8], plainLen)
	binary.BigEndian.PutUint32(header[8:12], cipherLen)
	if err := writeAll(dst, header[:]); err != nil {
		return err
	}
	return writeAll(dst, ciphertext)
}

func readExact(r io.Reader, n int) ([]byte, error) {
	buf := make([]byte, n)
	if _, err := io.ReadFull(r, buf); err != nil {
		if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
			return nil, ErrInvalidData
		}
		return nil, err
	}
	return buf, nil
}

func makeNonce(prefix [noncePrefixSize]byte, index uint32) [gcmNonceSize]byte {
	nonce := prefix
	var encodedIndex [4]byte
	binary.BigEndian.PutUint32(encodedIndex[:], index)
	for offset := range encodedIndex {
		nonce[len(nonce)-len(encodedIndex)+offset] ^= encodedIndex[offset]
	}
	return nonce
}

func writeAll(dst io.Writer, value []byte) error {
	for len(value) > 0 {
		n, err := dst.Write(value)
		if n > 0 {
			value = value[n:]
		}
		if err != nil {
			return err
		}
		if n == 0 {
			return io.ErrShortWrite
		}
	}
	return nil
}

func makeAAD(header []byte, index, plainLen uint32, final bool) []byte {
	aad := make([]byte, 0, len(header)+9)
	aad = append(aad, header...)
	var tmp [9]byte
	binary.BigEndian.PutUint32(tmp[0:4], index)
	binary.BigEndian.PutUint32(tmp[4:8], plainLen)
	if final {
		tmp[8] = 1
	}
	aad = append(aad, tmp[:]...)
	return aad
}
