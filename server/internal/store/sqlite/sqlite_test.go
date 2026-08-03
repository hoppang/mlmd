package sqlite_test

import (
	"context"
	"encoding/base64"
	"path/filepath"
	"testing"

	"github.com/hoppang/mlmd/server/internal/auth"
	"github.com/hoppang/mlmd/server/internal/model"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

func TestStateSurvivesStoreRestart(t *testing.T) {
	ctx := context.Background()
	databasePath := filepath.Join(t.TempDir(), "restart.db")
	secret, tokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}

	firstStore, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	space, device, err := firstStore.CreateSpace(
		ctx,
		"Family",
		"550e8400-e29b-41d4-a716-446655440000",
		"11111111-2222-4333-8444-555555555555",
		"Phone",
		tokenHash,
	)
	if err != nil {
		t.Fatal(err)
	}
	envelope := model.OutgoingEnvelope{
		EnvelopeVersion: 1,
		ChangeID:        "550e8400-e29b-41d4-a716-446655440010",
		SourceDeviceID:  device.ID,
		Nonce:           base64.RawURLEncoding.EncodeToString(make([]byte, 24)),
		Ciphertext:      base64.RawURLEncoding.EncodeToString(make([]byte, 16)),
	}
	if _, err := firstStore.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{envelope}, 200); err != nil {
		t.Fatal(err)
	}
	if err := firstStore.Close(); err != nil {
		t.Fatal(err)
	}

	reopened, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	defer reopened.Close()
	parsedDeviceID, parsedHash, err := auth.ParseDeviceToken(device.ID + "." + secret)
	if err != nil {
		t.Fatal(err)
	}
	authenticated, err := reopened.AuthenticateDevice(ctx, parsedDeviceID, parsedHash)
	if err != nil || authenticated.ID != device.ID {
		t.Fatalf("device authentication after restart failed: device=%#v err=%v", authenticated, err)
	}
	result, err := reopened.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{envelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(result.AcknowledgedChangeIDs) != 1 || len(result.Incoming) != 1 || result.Incoming[0].ServerSeq != 1 {
		t.Fatalf("state was not restored idempotently: %#v", result)
	}
}
