package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"strings"
)

var ErrMalformedToken = errors.New("malformed device token")

func NewDeviceToken(deviceID string) (string, []byte, error) {
	secret, hash, err := NewSecret()
	if err != nil {
		return "", nil, err
	}
	return deviceID + "." + secret, hash, nil
}

func NewSecret() (string, []byte, error) {
	secret := make([]byte, 32)
	if _, err := rand.Read(secret); err != nil {
		return "", nil, err
	}
	encoded := base64.RawURLEncoding.EncodeToString(secret)
	return encoded, HashSecret(encoded), nil
}

func ParseDeviceToken(token string) (string, []byte, error) {
	return ParseToken(token)
}

func ParseToken(token string) (string, []byte, error) {
	tokenID, secret, ok := strings.Cut(token, ".")
	if !ok || tokenID == "" || secret == "" || strings.Contains(secret, ".") {
		return "", nil, ErrMalformedToken
	}
	decoded, err := base64.RawURLEncoding.DecodeString(secret)
	if err != nil || len(decoded) != 32 {
		return "", nil, ErrMalformedToken
	}
	return tokenID, HashSecret(secret), nil
}

func HashSecret(secret string) []byte {
	sum := sha256.Sum256([]byte(secret))
	return sum[:]
}
