package restore

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"testing"

	backupcrypto "github.com/hoppang/mlmd/server/internal/backup"
	"github.com/hoppang/mlmd/server/internal/filelock"
	storepkg "github.com/hoppang/mlmd/server/internal/store"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

func TestDatabaseRestoresBackupAndPreservesLiveDatabase(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	directory := t.TempDir()
	key := testKey(1)
	backupPath := filepath.Join(directory, "source.mlmd-backup")
	createEncryptedBackup(t, ctx, filepath.Join(directory, "source.db"), backupPath, key, "source-space", "source-device", []byte("source-token"))

	livePath := filepath.Join(directory, "live.db")
	createDatabase(t, ctx, livePath, "live-space", "live-device", []byte("live-token"))

	result, err := Database(ctx, backupPath, livePath, key)
	if err != nil {
		t.Fatalf("restore database: %v", err)
	}
	if result.PreservedDirectory == "" {
		t.Fatal("expected preserved database directory")
	}
	assertDevice(t, ctx, livePath, "source-device", []byte("source-token"), true)
	assertDevice(t, ctx, livePath, "live-device", []byte("live-token"), false)

	preservedPath := filepath.Join(result.PreservedDirectory, filepath.Base(livePath))
	assertDevice(t, ctx, preservedPath, "live-device", []byte("live-token"), true)
}

func TestDatabaseRejectsInvalidBackupWithoutTouchingLiveDatabase(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	directory := t.TempDir()
	key := testKey(2)
	backupPath := filepath.Join(directory, "source.mlmd-backup")
	createEncryptedBackup(t, ctx, filepath.Join(directory, "source.db"), backupPath, key, "source-space", "source-device", []byte("source-token"))

	tests := []struct {
		name    string
		prepare func(*testing.T) (string, []byte)
	}{
		{
			name: "wrong key",
			prepare: func(t *testing.T) (string, []byte) {
				return backupPath, testKey(3)
			},
		},
		{
			name: "tampered ciphertext",
			prepare: func(t *testing.T) (string, []byte) {
				tampered := filepath.Join(directory, "tampered.mlmd-backup")
				contents, err := os.ReadFile(backupPath)
				if err != nil {
					t.Fatal(err)
				}
				contents[len(contents)/2] ^= 0xff
				if err := os.WriteFile(tampered, contents, 0o600); err != nil {
					t.Fatal(err)
				}
				return tampered, key
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			livePath := filepath.Join(directory, test.name+"-live.db")
			createDatabase(t, ctx, livePath, "live-space", "live-device", []byte("live-token"))
			input, restoreKey := test.prepare(t)
			if _, err := Database(ctx, input, livePath, restoreKey); err == nil {
				t.Fatal("expected restore failure")
			}
			assertDevice(t, ctx, livePath, "live-device", []byte("live-token"), true)
			matches, err := filepath.Glob(livePath + ".pre-restore-*")
			if err != nil {
				t.Fatal(err)
			}
			if len(matches) != 0 {
				t.Fatalf("invalid backup created preservation directories: %v", matches)
			}
		})
	}
}

func TestDatabaseRefusesActiveServerOrMaintenance(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	directory := t.TempDir()
	key := testKey(4)
	backupPath := filepath.Join(directory, "source.mlmd-backup")
	createEncryptedBackup(t, ctx, filepath.Join(directory, "source.db"), backupPath, key, "source-space", "source-device", []byte("source-token"))

	for _, lockSuffix := range []string{".server.lock", ".maintenance.lock"} {
		t.Run(lockSuffix, func(t *testing.T) {
			livePath := filepath.Join(directory, lockSuffix+"-live.db")
			createDatabase(t, ctx, livePath, "live-space", "live-device", []byte("live-token"))
			var lock *filelock.Lock
			var err error
			if lockSuffix == ".maintenance.lock" {
				lock, err = filelock.AcquireShared(livePath + lockSuffix)
			} else {
				lock, err = filelock.Acquire(livePath + lockSuffix)
			}
			if err != nil {
				t.Fatal(err)
			}
			defer lock.Release()

			_, err = Database(ctx, backupPath, livePath, key)
			if !errors.Is(err, ErrDatabaseInUse) {
				t.Fatalf("expected ErrDatabaseInUse, got %v", err)
			}
			assertDevice(t, ctx, livePath, "live-device", []byte("live-token"), true)
		})
	}
}

func TestDatabaseRejectsNewerSchemaWithoutTouchingLiveDatabase(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	directory := t.TempDir()
	key := testKey(5)
	sourcePath := filepath.Join(directory, "future.db")
	createDatabase(t, ctx, sourcePath, "source-space", "source-device", []byte("source-token"))
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(sourcePath))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, `PRAGMA user_version = 999`); err != nil {
		db.Close()
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}
	backupPath := filepath.Join(directory, "future.mlmd-backup")
	input, err := os.Open(sourcePath)
	if err != nil {
		t.Fatal(err)
	}
	output, err := os.OpenFile(backupPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		input.Close()
		t.Fatal(err)
	}
	if err := backupcrypto.Encrypt(ctx, output, input, key); err != nil {
		output.Close()
		input.Close()
		t.Fatal(err)
	}
	if err := output.Close(); err != nil {
		input.Close()
		t.Fatal(err)
	}
	if err := input.Close(); err != nil {
		t.Fatal(err)
	}

	livePath := filepath.Join(directory, "live.db")
	createDatabase(t, ctx, livePath, "live-space", "live-device", []byte("live-token"))
	if _, err := Database(ctx, backupPath, livePath, key); err == nil {
		t.Fatal("expected newer schema to be rejected")
	}
	assertDevice(t, ctx, livePath, "live-device", []byte("live-token"), true)
}

func TestVerifyChecksBackupWithoutTouchingLiveDatabase(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	directory := t.TempDir()
	key := testKey(6)
	backupPath := filepath.Join(directory, "source.mlmd-backup")
	createEncryptedBackup(t, ctx, filepath.Join(directory, "source.db"), backupPath, key, "source-space", "source-device", []byte("source-token"))
	livePath := filepath.Join(directory, "live.db")
	createDatabase(t, ctx, livePath, "live-space", "live-device", []byte("live-token"))

	if err := Verify(ctx, backupPath, directory, key); err != nil {
		t.Fatalf("verify backup: %v", err)
	}
	assertDevice(t, ctx, livePath, "live-device", []byte("live-token"), true)
	if err := Verify(ctx, backupPath, directory, testKey(7)); err == nil {
		t.Fatal("expected wrong key verification to fail")
	}
	workspaces, err := filepath.Glob(filepath.Join(directory, ".mlmd-restore-work-*"))
	if err != nil {
		t.Fatal(err)
	}
	if len(workspaces) != 0 {
		t.Fatalf("verification left plaintext workspaces: %v", workspaces)
	}
}

func TestReplaceDatabaseRollsBackWhenCandidateCannotBeInstalled(t *testing.T) {
	t.Parallel()
	directory := t.TempDir()
	databasePath := filepath.Join(directory, "live.db")
	original := []byte("original database bytes")
	if err := os.WriteFile(databasePath, original, 0o600); err != nil {
		t.Fatal(err)
	}

	if _, err := replaceDatabase(databasePath, filepath.Join(directory, "missing.db")); err == nil {
		t.Fatal("expected replace failure")
	}
	contents, err := os.ReadFile(databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != string(original) {
		t.Fatalf("database was not rolled back: %q", contents)
	}
	matches, err := filepath.Glob(databasePath + ".pre-restore-*")
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) != 0 {
		t.Fatalf("rollback left preservation directories: %v", matches)
	}
}

func TestReplaceDatabasePreservesSQLiteSidecars(t *testing.T) {
	t.Parallel()
	directory := t.TempDir()
	databasePath := filepath.Join(directory, "live.db")
	candidatePath := filepath.Join(directory, "candidate.db")
	files := map[string]string{
		databasePath:          "old database",
		databasePath + "-wal": "old wal",
		databasePath + "-shm": "old shm",
		candidatePath:         "new database",
	}
	for path, contents := range files {
		if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
			t.Fatal(err)
		}
	}

	preservedDirectory, err := replaceDatabase(databasePath, candidatePath)
	if err != nil {
		t.Fatal(err)
	}
	installed, err := os.ReadFile(databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if string(installed) != "new database" {
		t.Fatalf("unexpected installed database: %q", installed)
	}
	for path, want := range map[string]string{
		filepath.Join(preservedDirectory, "live.db"):     "old database",
		filepath.Join(preservedDirectory, "live.db-wal"): "old wal",
		filepath.Join(preservedDirectory, "live.db-shm"): "old shm",
	} {
		contents, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		if string(contents) != want {
			t.Fatalf("unexpected preserved file %q: %q", path, contents)
		}
	}
}

func createEncryptedBackup(t *testing.T, ctx context.Context, databasePath, backupPath string, key []byte, spaceID, deviceID string, token []byte) {
	t.Helper()
	store := createOpenDatabase(t, ctx, databasePath, spaceID, deviceID, token)
	if err := store.BackupEncrypted(ctx, backupPath, key); err != nil {
		store.Close()
		t.Fatalf("create encrypted backup: %v", err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
}

func createDatabase(t *testing.T, ctx context.Context, path, spaceID, deviceID string, token []byte) {
	t.Helper()
	store := createOpenDatabase(t, ctx, path, spaceID, deviceID, token)
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
}

func createOpenDatabase(t *testing.T, ctx context.Context, path, spaceID, deviceID string, token []byte) *sqlite.Store {
	t.Helper()
	store, err := sqlite.Open(ctx, path)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := store.CreateSpace(ctx, "Family", spaceID, deviceID, "Device", token); err != nil {
		store.Close()
		t.Fatal(err)
	}
	return store
}

func assertDevice(t *testing.T, ctx context.Context, path, deviceID string, token []byte, want bool) {
	t.Helper()
	store, err := sqlite.Open(ctx, path)
	if err != nil {
		t.Fatalf("open database %q: %v", path, err)
	}
	defer store.Close()
	_, err = store.AuthenticateDevice(ctx, deviceID, token)
	if want && err != nil {
		t.Fatalf("authenticate %q: %v", deviceID, err)
	}
	if !want && !errors.Is(err, storepkg.ErrUnauthorized) {
		t.Fatalf("expected %q to be absent, got %v", deviceID, err)
	}
}

func testKey(seed byte) []byte {
	key := make([]byte, 32)
	for index := range key {
		key[index] = seed + byte(index)
	}
	return key
}
