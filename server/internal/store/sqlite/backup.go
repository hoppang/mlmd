package sqlite

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

var ErrBackupDestinationExists = errors.New("backup destination already exists")

// Backup writes a transactionally consistent snapshot of the live database.
// The destination is published only after SQLite's integrity check succeeds.
func (s *Store) Backup(ctx context.Context, destination string) error {
	absDestination, err := filepath.Abs(destination)
	if err != nil {
		return fmt.Errorf("resolve backup destination: %w", err)
	}
	if _, err := os.Lstat(absDestination); err == nil {
		return ErrBackupDestinationExists
	} else if !errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("inspect backup destination: %w", err)
	}

	destinationDir := filepath.Dir(absDestination)
	if err := os.MkdirAll(destinationDir, 0o700); err != nil {
		return fmt.Errorf("create backup directory: %w", err)
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
	if err := validateBackup(ctx, temporaryPath); err != nil {
		return err
	}
	if err := syncFile(temporaryPath); err != nil {
		return fmt.Errorf("sync backup to disk: %w", err)
	}
	if err := os.Link(temporaryPath, absDestination); err != nil {
		if errors.Is(err, fs.ErrExist) {
			return ErrBackupDestinationExists
		}
		return fmt.Errorf("publish backup: %w", err)
	}
	return nil
}

func validateBackup(ctx context.Context, path string) error {
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
	return nil
}

func syncFile(path string) error {
	file, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return err
	}
	defer file.Close()
	return file.Sync()
}
