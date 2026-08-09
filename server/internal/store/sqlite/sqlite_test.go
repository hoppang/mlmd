package sqlite_test

import (
	"context"
	"encoding/base64"
	"errors"
	"os"
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

func TestBackupCapturesLiveWALSnapshot(t *testing.T) {
	ctx := context.Background()
	tempDir := t.TempDir()
	databasePath := filepath.Join(tempDir, "live.db")
	backupPath := filepath.Join(tempDir, "backups", "snapshot.db")
	_, tokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}

	liveStore, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	defer liveStore.Close()
	space, device, err := liveStore.CreateSpace(
		ctx,
		"Family",
		"550e8400-e29b-41d4-a716-446655440020",
		"11111111-2222-4333-8444-555555555556",
		"Phone",
		tokenHash,
	)
	if err != nil {
		t.Fatal(err)
	}
	firstEnvelope := model.OutgoingEnvelope{
		EnvelopeVersion: 1,
		ChangeID:        "550e8400-e29b-41d4-a716-446655440021",
		SourceDeviceID:  device.ID,
		Nonce:           base64.RawURLEncoding.EncodeToString(make([]byte, 24)),
		Ciphertext:      base64.RawURLEncoding.EncodeToString(make([]byte, 16)),
	}
	if _, err := liveStore.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{firstEnvelope}, 200); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(databasePath + "-wal"); err != nil {
		t.Fatalf("expected live WAL file: %v", err)
	}

	backupSource, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := backupSource.Backup(ctx, backupPath); err != nil {
		backupSource.Close()
		t.Fatal(err)
	}
	if err := backupSource.Close(); err != nil {
		t.Fatal(err)
	}
	secondEnvelope := firstEnvelope
	secondEnvelope.ChangeID = "550e8400-e29b-41d4-a716-446655440022"
	if _, err := liveStore.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{secondEnvelope}, 200); err != nil {
		t.Fatal(err)
	}

	backupStore, err := sqlite.Open(ctx, backupPath)
	if err != nil {
		t.Fatal(err)
	}
	defer backupStore.Close()
	if _, err := backupStore.AuthenticateDevice(ctx, device.ID, tokenHash); err != nil {
		t.Fatalf("backup did not preserve device authentication: %v", err)
	}
	result, err := backupStore.Exchange(ctx, space.ID, device.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Incoming) != 1 || result.Incoming[0].ChangeID != firstEnvelope.ChangeID {
		t.Fatalf("backup is not the expected point-in-time snapshot: %#v", result.Incoming)
	}
}

func TestBackupRefusesToOverwriteDestination(t *testing.T) {
	ctx := context.Background()
	tempDir := t.TempDir()
	store, err := sqlite.Open(ctx, filepath.Join(tempDir, "source.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()

	destination := filepath.Join(tempDir, "existing.db")
	if err := os.WriteFile(destination, []byte("keep me"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := store.Backup(ctx, destination); !errors.Is(err, sqlite.ErrBackupDestinationExists) {
		t.Fatalf("expected destination-exists error, got %v", err)
	}
	contents, err := os.ReadFile(destination)
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != "keep me" {
		t.Fatalf("existing destination was modified: %q", contents)
	}
}
