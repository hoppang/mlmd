package sqlite

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	backupcrypto "github.com/hoppang/mlmd/server/internal/backup"
	"github.com/hoppang/mlmd/server/migrations"
)

var ErrBackupDestinationExists = errors.New("backup destination already exists")

// Backup writes a transactionally consistent snapshot of the live database.
// The destination is published only after SQLite's integrity check succeeds.
func (s *Store) Backup(ctx context.Context, destination string) error {
	absDestination, destinationDir, err := prepareBackupDestination(destination)
	if err != nil {
		return err
	}
	temporaryFile, err := os.CreateTemp(
		destinationDir,
		"."+filepath.Base(absDestination)+".tmp-*",
	)
	if err != nil {
		return fmt.Errorf("reserve temporary backup path: %w", err)
	}
	temporaryPath := temporaryFile.Name()
	if err := temporaryFile.Close(); err != nil {
		_ = os.Remove(temporaryPath)
		return fmt.Errorf("close temporary backup file: %w", err)
	}
	defer os.Remove(temporaryPath)

	if _, err := s.db.ExecContext(ctx, `VACUUM INTO ?`, temporaryPath); err != nil {
		return fmt.Errorf("create sqlite snapshot: %w", err)
	}
	if err := os.Chmod(temporaryPath, 0o600); err != nil {
		return fmt.Errorf("restrict backup permissions: %w", err)
	}
	if err := ValidateDatabase(ctx, temporaryPath); err != nil {
		return err
	}
	if err := syncFile(temporaryPath); err != nil {
		return fmt.Errorf("sync backup to disk: %w", err)
	}
	return publishBackup(temporaryPath, absDestination)
}

// BackupEncrypted creates a validated SQLite snapshot and publishes only its
// authenticated encrypted representation. The raw snapshot is short-lived in
// a private temporary directory and is removed before this method returns.
func (s *Store) BackupEncrypted(ctx context.Context, destination string, key []byte) error {
	if len(key) != 32 {
		return fmt.Errorf("encrypt backup: key must be exactly 32 bytes")
	}
	absDestination, destinationDir, err := prepareBackupDestination(destination)
	if err != nil {
		return err
	}
	workDir, err := os.MkdirTemp(
		filepath.Dir(s.databasePath),
		".mlmd-backup-work-*",
	)
	if err != nil {
		return fmt.Errorf("create private backup workspace: %w", err)
	}
	defer os.RemoveAll(workDir)
	plainSnapshot := filepath.Join(workDir, "snapshot.db")
	if err := s.Backup(ctx, plainSnapshot); err != nil {
		return err
	}

	plainFile, err := os.Open(plainSnapshot)
	if err != nil {
		return fmt.Errorf("open sqlite snapshot for encryption: %w", err)
	}
	defer plainFile.Close()
	encryptedFile, err := os.CreateTemp(
		destinationDir,
		"."+filepath.Base(absDestination)+".tmp-*",
	)
	if err != nil {
		return fmt.Errorf("create encrypted backup file: %w", err)
	}
	encryptedPath := encryptedFile.Name()
	defer os.Remove(encryptedPath)
	if err := encryptedFile.Chmod(0o600); err != nil {
		encryptedFile.Close()
		return fmt.Errorf("restrict encrypted backup permissions: %w", err)
	}
	if err := backupcrypto.Encrypt(ctx, encryptedFile, plainFile, key); err != nil {
		encryptedFile.Close()
		return fmt.Errorf("encrypt backup: %w", err)
	}
	if err := encryptedFile.Sync(); err != nil {
		encryptedFile.Close()
		return fmt.Errorf("sync encrypted backup to disk: %w", err)
	}
	if err := encryptedFile.Close(); err != nil {
		return fmt.Errorf("close encrypted backup: %w", err)
	}
	return publishBackup(encryptedPath, absDestination)
}

func prepareBackupDestination(destination string) (string, string, error) {
	absDestination, err := filepath.Abs(destination)
	if err != nil {
		return "", "", fmt.Errorf("resolve backup destination: %w", err)
	}
	if _, err := os.Lstat(absDestination); err == nil {
		return "", "", ErrBackupDestinationExists
	} else if !errors.Is(err, fs.ErrNotExist) {
		return "", "", fmt.Errorf("inspect backup destination: %w", err)
	}
	destinationDir := filepath.Dir(absDestination)
	if err := os.MkdirAll(destinationDir, 0o700); err != nil {
		return "", "", fmt.Errorf("create backup directory: %w", err)
	}
	return absDestination, destinationDir, nil
}

func publishBackup(source, destination string) error {
	if err := os.Link(source, destination); err != nil {
		if errors.Is(err, fs.ErrExist) {
			return ErrBackupDestinationExists
		}
		return fmt.Errorf("publish backup: %w", err)
	}
	return nil
}

// ValidateDatabase verifies SQLite integrity and the minimum MLMD schema
// without mutating the candidate.
func ValidateDatabase(ctx context.Context, path string) error {
	dsn := "file:" + filepath.ToSlash(path) + "?mode=ro&_pragma=query_only(1)"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return fmt.Errorf("open backup for validation: %w", err)
	}
	defer db.Close()
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)

	var result string
	if err := db.QueryRowContext(ctx, `PRAGMA quick_check`).Scan(&result); err != nil {
		return fmt.Errorf("validate backup: %w", err)
	}
	if result != "ok" {
		return fmt.Errorf("validate backup: quick_check returned %q", result)
	}
	if err := db.QueryRowContext(ctx, `PRAGMA integrity_check`).Scan(&result); err != nil {
		return fmt.Errorf("validate backup integrity: %w", err)
	}
	if result != "ok" {
		return fmt.Errorf("validate backup: integrity_check returned %q", result)
	}
	var userVersion int
	if err := db.QueryRowContext(ctx, `PRAGMA user_version`).Scan(&userVersion); err != nil {
		return fmt.Errorf("read backup schema version: %w", err)
	}
	if userVersion > migrations.CurrentVersion {
		return fmt.Errorf(
			"backup schema version %d is newer than supported version %d",
			userVersion,
			migrations.CurrentVersion,
		)
	}
	for _, table := range []string{
		"family_spaces",
		"devices",
		"invites",
		"changes",
		"device_cursors",
		"readiness_probe",
	} {
		var found int
		if err := db.QueryRowContext(
			ctx,
			`SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = ?`,
			table,
		).Scan(&found); err != nil {
			return fmt.Errorf("validate MLMD table %q: %w", table, err)
		}
	}
	rows, err := db.QueryContext(ctx, `PRAGMA foreign_key_check`)
	if err != nil {
		return fmt.Errorf("validate backup foreign keys: %w", err)
	}
	defer rows.Close()
	if rows.Next() {
		return fmt.Errorf("validate backup: foreign key violations found")
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("validate backup foreign keys: %w", err)
	}
	return nil
}

// PrepareRestore validates, migrates, checkpoints, and revalidates a decrypted
// database before it is eligible to replace the live database.
func PrepareRestore(ctx context.Context, path string) error {
	if err := ValidateDatabase(ctx, path); err != nil {
		return err
	}
	store, err := Open(ctx, path)
	if err != nil {
		return fmt.Errorf("migrate restored database: %w", err)
	}
	if _, err := store.db.ExecContext(ctx, `PRAGMA wal_checkpoint(TRUNCATE)`); err != nil {
		store.Close()
		return fmt.Errorf("checkpoint restored database: %w", err)
	}
	if err := store.Close(); err != nil {
		return fmt.Errorf("close restored database: %w", err)
	}
	for _, sidecar := range []string{path + "-wal", path + "-shm"} {
		if err := os.Remove(sidecar); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return fmt.Errorf("remove restored database sidecar: %w", err)
		}
	}
	if err := syncFile(path); err != nil {
		return fmt.Errorf("sync restored database: %w", err)
	}
	return ValidateDatabase(ctx, path)
}

func syncFile(path string) error {
	file, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return err
	}
	defer file.Close()
	return file.Sync()
}
