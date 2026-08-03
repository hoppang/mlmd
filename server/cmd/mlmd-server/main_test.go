package main

import (
	"context"
	"io"
	"log/slog"
	"path/filepath"
	"testing"

	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

func TestRunBackupCreatesSnapshot(t *testing.T) {
	tempDir := t.TempDir()
	databasePath := filepath.Join(tempDir, "source.db")
	backupPath := filepath.Join(tempDir, "backups", "snapshot.db")
	store, err := sqlite.Open(context.Background(), databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MLMD_DATABASE_PATH", databasePath)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))

	if err := runBackup(logger, []string{"--output", backupPath}); err != nil {
		t.Fatal(err)
	}
	backupStore, err := sqlite.Open(context.Background(), backupPath)
	if err != nil {
		t.Fatal(err)
	}
	defer backupStore.Close()
	if err := backupStore.Ready(context.Background()); err != nil {
		t.Fatalf("backup is not ready: %v", err)
	}
}
