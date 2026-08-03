package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"errors"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/hoppang/mlmd/server/internal/autobackup"
	backupcrypto "github.com/hoppang/mlmd/server/internal/backup"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

func TestRunBackupCreatesSnapshot(t *testing.T) {
	tempDir := t.TempDir()
	databasePath := filepath.Join(tempDir, "source.db")
	backupPath := filepath.Join(tempDir, "backups", "snapshot.mlmd-backup")
	restoredPath := filepath.Join(tempDir, "restored.db")
	backupKey := bytes.Repeat([]byte{0x42}, 32)
	store, err := sqlite.Open(context.Background(), databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MLMD_DATABASE_PATH", databasePath)
	t.Setenv("MLMD_BACKUP_KEY", base64.RawURLEncoding.EncodeToString(backupKey))
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))

	if err := runBackup(logger, []string{"--output", backupPath}); err != nil {
		t.Fatal(err)
	}
	encryptedContents, err := os.ReadFile(backupPath)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.HasPrefix(encryptedContents, []byte("SQLite format 3")) {
		t.Fatal("backup output contains a plaintext SQLite header")
	}
	workspaces, err := filepath.Glob(filepath.Join(tempDir, ".mlmd-backup-work-*"))
	if err != nil {
		t.Fatal(err)
	}
	if len(workspaces) != 0 {
		t.Fatalf("plaintext backup workspace was not removed: %v", workspaces)
	}
	encryptedFile, err := os.Open(backupPath)
	if err != nil {
		t.Fatal(err)
	}
	restoredFile, err := os.OpenFile(restoredPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		encryptedFile.Close()
		t.Fatal(err)
	}
	if err := backupcrypto.Decrypt(context.Background(), restoredFile, encryptedFile, backupKey); err != nil {
		restoredFile.Close()
		encryptedFile.Close()
		t.Fatal(err)
	}
	if err := restoredFile.Close(); err != nil {
		encryptedFile.Close()
		t.Fatal(err)
	}
	if err := encryptedFile.Close(); err != nil {
		t.Fatal(err)
	}
	backupStore, err := sqlite.Open(context.Background(), restoredPath)
	if err != nil {
		t.Fatal(err)
	}
	defer backupStore.Close()
	if err := backupStore.Ready(context.Background()); err != nil {
		t.Fatalf("backup is not ready: %v", err)
	}
}

func TestGenerateBackupKeyCreatesBase64URLKeyWithoutOverwrite(t *testing.T) {
	keyPath := filepath.Join(t.TempDir(), "keys", "backup.key")
	if err := runGenerateBackupKey([]string{"--output", keyPath}); err != nil {
		t.Fatal(err)
	}
	contents, err := os.ReadFile(keyPath)
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := base64.RawURLEncoding.Strict().DecodeString(string(contents))
	if err != nil || len(decoded) != 32 {
		t.Fatalf("invalid generated key: size=%d err=%v", len(decoded), err)
	}
	t.Setenv("MLMD_BACKUP_KEY", "")
	loaded, err := loadBackupKey(keyPath)
	if err != nil || !bytes.Equal(loaded, decoded) {
		t.Fatalf("generated key could not be loaded: %v", err)
	}
	original := append([]byte(nil), contents...)
	if err := runGenerateBackupKey([]string{"--output", keyPath}); err == nil {
		t.Fatal("expected existing key file to be rejected")
	}
	contents, err = os.ReadFile(keyPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(contents, original) {
		t.Fatal("existing key file was modified")
	}
}

func TestRunRestoreInstallsBackupAndPreservesExistingDatabase(t *testing.T) {
	tempDir := t.TempDir()
	ctx := context.Background()
	key := bytes.Repeat([]byte{0x51}, 32)
	sourcePath := filepath.Join(tempDir, "source.db")
	backupPath := filepath.Join(tempDir, "source.mlmd-backup")
	sourceStore, err := sqlite.Open(ctx, sourcePath)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := sourceStore.CreateSpace(ctx, "Source", "source-space", "source-device", "Source device", []byte("source-token")); err != nil {
		sourceStore.Close()
		t.Fatal(err)
	}
	if err := sourceStore.BackupEncrypted(ctx, backupPath, key); err != nil {
		sourceStore.Close()
		t.Fatal(err)
	}
	if err := sourceStore.Close(); err != nil {
		t.Fatal(err)
	}

	livePath := filepath.Join(tempDir, "live.db")
	liveStore, err := sqlite.Open(ctx, livePath)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := liveStore.CreateSpace(ctx, "Live", "live-space", "live-device", "Live device", []byte("live-token")); err != nil {
		liveStore.Close()
		t.Fatal(err)
	}
	if err := liveStore.Close(); err != nil {
		t.Fatal(err)
	}

	t.Setenv("MLMD_DATABASE_PATH", livePath)
	t.Setenv("MLMD_BACKUP_KEY", base64.RawURLEncoding.EncodeToString(key))
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	if err := runRestore(logger, []string{"--input", backupPath}); err != nil {
		t.Fatal(err)
	}
	restoredStore, err := sqlite.Open(ctx, livePath)
	if err != nil {
		t.Fatal(err)
	}
	defer restoredStore.Close()
	if _, err := restoredStore.AuthenticateDevice(ctx, "source-device", []byte("source-token")); err != nil {
		t.Fatalf("restored source device is unavailable: %v", err)
	}
	matches, err := filepath.Glob(livePath + ".pre-restore-*")
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) != 1 {
		t.Fatalf("expected one preserved database directory, got %v", matches)
	}
}

func TestRunBackupSchedulerOnceCreatesManagedBackup(t *testing.T) {
	tempDir := t.TempDir()
	databasePath := filepath.Join(tempDir, "mlmd.db")
	store, err := sqlite.Open(context.Background(), databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MLMD_DATABASE_PATH", databasePath)
	t.Setenv("MLMD_BACKUP_KEY", base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{0x61}, 32)))
	backupDirectory := filepath.Join(tempDir, "backups")
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))

	if err := runBackupScheduler(logger, []string{"--directory", backupDirectory, "--once"}); err != nil {
		t.Fatal(err)
	}
	matches, err := filepath.Glob(filepath.Join(backupDirectory, "mlmd-auto-*.mlmd-backup"))
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) != 1 {
		t.Fatalf("expected one managed backup, got %v", matches)
	}
}

func TestBackupSchedulerLoopContinuesAfterCycleFailure(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	attempts := 0
	err := backupSchedulerLoop(ctx, logger, time.Millisecond, func(context.Context, time.Time) (autobackup.Result, error) {
		attempts++
		if attempts == 3 {
			cancel()
		}
		return autobackup.Result{}, errors.New("injected backup failure")
	})
	if err != nil {
		t.Fatal(err)
	}
	if attempts != 3 {
		t.Fatalf("scheduler stopped after failure: attempts=%d", attempts)
	}
}

func TestLoadBackupKeyRejectsAmbiguousOrInvalidInput(t *testing.T) {
	t.Setenv("MLMD_BACKUP_KEY", "invalid")
	if _, err := loadBackupKey(""); err == nil {
		t.Fatal("expected invalid environment key to fail")
	}
	keyPath := filepath.Join(t.TempDir(), "backup.key")
	valid := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{0x11}, 32))
	if err := os.WriteFile(keyPath, []byte(valid), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := loadBackupKey(keyPath); err == nil {
		t.Fatal("expected simultaneous key file and environment key to fail")
	}
}
