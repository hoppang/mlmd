package backup_test

import (
	"bytes"
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
	"testing"

	"github.com/hoppang/mlmd/server/internal/backup"
)

func TestRoundTripAcrossSizes(t *testing.T) {
	ctx := context.Background()
	key := testKey()
	cases := []int{0, 1, 17, 1024, 1<<20 - 1, 1 << 20, 1<<20 + 7, 2<<20 + 13}
	for _, size := range cases {
		t.Run(fmt.Sprintf("size_%d", size), func(t *testing.T) {
			plain := make([]byte, size)
			if _, err := rand.Read(plain); err != nil {
				t.Fatal(err)
			}
			var encrypted bytes.Buffer
			if err := backup.Encrypt(ctx, &encrypted, bytes.NewReader(plain), key); err != nil {
				t.Fatal(err)
			}
			var decrypted bytes.Buffer
			if err := backup.Decrypt(ctx, &decrypted, bytes.NewReader(encrypted.Bytes()), key); err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(decrypted.Bytes(), plain) {
				t.Fatalf("round trip mismatch for size %d", size)
			}
		})
	}
}

func TestWrongKeyFails(t *testing.T) {
	ctx := context.Background()
	key := testKey()
	otherKey := bytes.Repeat([]byte{0x24}, 32)
	plain := []byte("hello world")
	var encrypted bytes.Buffer
	if err := backup.Encrypt(ctx, &encrypted, bytes.NewReader(plain), key); err != nil {
		t.Fatal(err)
	}
	var decrypted bytes.Buffer
	if err := backup.Decrypt(ctx, &decrypted, bytes.NewReader(encrypted.Bytes()), otherKey); !errors.Is(err, backup.ErrInvalidData) {
		t.Fatalf("expected invalid data with wrong key, got %v", err)
	}
}

func TestEncryptionUsesFreshNonceForEveryBackup(t *testing.T) {
	ctx := context.Background()
	key := testKey()
	plain := []byte("same backup contents")
	var first, second bytes.Buffer
	if err := backup.Encrypt(ctx, &first, bytes.NewReader(plain), key); err != nil {
		t.Fatal(err)
	}
	if err := backup.Encrypt(ctx, &second, bytes.NewReader(plain), key); err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(first.Bytes(), second.Bytes()) {
		t.Fatal("two backups reused the same nonce")
	}
}

func TestCiphertextTamperFails(t *testing.T) {
	ctx := context.Background()
	key := testKey()
	plain := []byte("tamper me")
	var encrypted bytes.Buffer
	if err := backup.Encrypt(ctx, &encrypted, bytes.NewReader(plain), key); err != nil {
		t.Fatal(err)
	}
	data := encrypted.Bytes()
	data[len(data)/2] ^= 0x80
	var decrypted bytes.Buffer
	if err := backup.Decrypt(ctx, &decrypted, bytes.NewReader(data), key); !errors.Is(err, backup.ErrInvalidData) {
		t.Fatalf("expected invalid data after tamper, got %v", err)
	}
}

func TestTruncationFails(t *testing.T) {
	ctx := context.Background()
	key := testKey()
	plain := bytes.Repeat([]byte("a"), 4096)
	var encrypted bytes.Buffer
	if err := backup.Encrypt(ctx, &encrypted, bytes.NewReader(plain), key); err != nil {
		t.Fatal(err)
	}
	data := encrypted.Bytes()
	truncated := data[:len(data)-5]
	var decrypted bytes.Buffer
	if err := backup.Decrypt(ctx, &decrypted, bytes.NewReader(truncated), key); !errors.Is(err, backup.ErrInvalidData) {
		t.Fatalf("expected invalid data after truncation, got %v", err)
	}
}

func TestInvalidKeyAndHeader(t *testing.T) {
	ctx := context.Background()
	if _, err := backup.New([]byte("short")); !errors.Is(err, backup.ErrInvalidKey) {
		t.Fatalf("expected invalid key, got %v", err)
	}
	if err := backup.Encrypt(ctx, io.Discard, bytes.NewReader(nil), []byte("short")); !errors.Is(err, backup.ErrInvalidKey) {
		t.Fatalf("expected invalid key from Encrypt, got %v", err)
	}
	if err := backup.Decrypt(ctx, io.Discard, bytes.NewReader([]byte("bad header")), testKey()); !errors.Is(err, backup.ErrInvalidData) && !errors.Is(err, backup.ErrUnsupported) {
		t.Fatalf("expected header failure, got %v", err)
	}
}

func testKey() []byte {
	return bytes.Repeat([]byte{0x42}, 32)
}
