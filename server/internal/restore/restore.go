package restore

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"time"

	backupcrypto "github.com/hoppang/mlmd/server/internal/backup"
	"github.com/hoppang/mlmd/server/internal/filelock"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

var ErrDatabaseInUse = errors.New("database is in use; stop the server and other maintenance commands before restoring")

type Result struct {
	PreservedDirectory string
}

// Database restores an encrypted backup only after it has been authenticated,
// validated, and migrated. Any existing database and its SQLite sidecars are
// retained in a sibling directory instead of being deleted.
func Database(ctx context.Context, inputPath, databasePath string, key []byte) (Result, error) {
	if len(key) != 32 {
		return Result{}, backupcrypto.ErrInvalidKey
	}
	absDatabase, err := filepath.Abs(databasePath)
	if err != nil {
		return Result{}, fmt.Errorf("resolve database path: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(absDatabase), 0o700); err != nil {
		return Result{}, fmt.Errorf("create database directory: %w", err)
	}

	serverLock, err := acquireRestoreLock(absDatabase + ".server.lock")
	if err != nil {
		return Result{}, err
	}
	defer serverLock.Release()
	maintenanceLock, err := acquireRestoreLock(absDatabase + ".maintenance.lock")
	if err != nil {
		return Result{}, err
	}
	defer maintenanceLock.Release()

	temporaryPath, cleanup, err := prepareCandidate(ctx, inputPath, filepath.Dir(absDatabase), key)
	if err != nil {
		return Result{}, err
	}
	defer cleanup()
	if err := ctx.Err(); err != nil {
		return Result{}, err
	}

	preservedDirectory, err := replaceDatabase(absDatabase, temporaryPath)
	if err != nil {
		return Result{}, err
	}
	return Result{PreservedDirectory: preservedDirectory}, nil
}

// Verify authenticates, decrypts, validates, and migrates a backup in an
// isolated private workspace without replacing any live database.
func Verify(ctx context.Context, inputPath, workspaceDirectory string, key []byte) error {
	if len(key) != 32 {
		return backupcrypto.ErrInvalidKey
	}
	_, cleanup, err := prepareCandidate(ctx, inputPath, workspaceDirectory, key)
	if cleanup != nil {
		defer cleanup()
	}
	return err
}

func prepareCandidate(ctx context.Context, inputPath, workspaceDirectory string, key []byte) (string, func(), error) {
	absInput, err := filepath.Abs(inputPath)
	if err != nil {
		return "", nil, fmt.Errorf("resolve restore input path: %w", err)
	}
	absWorkspace, err := filepath.Abs(workspaceDirectory)
	if err != nil {
		return "", nil, fmt.Errorf("resolve restore workspace: %w", err)
	}
	if err := os.MkdirAll(absWorkspace, 0o700); err != nil {
		return "", nil, fmt.Errorf("create restore workspace parent: %w", err)
	}
	workspace, err := os.MkdirTemp(absWorkspace, ".mlmd-restore-work-*")
	if err != nil {
		return "", nil, fmt.Errorf("create private restore workspace: %w", err)
	}
	cleanup := func() { _ = os.RemoveAll(workspace) }
	if err := os.Chmod(workspace, 0o700); err != nil {
		cleanup()
		return "", nil, fmt.Errorf("restrict restore workspace permissions: %w", err)
	}
	input, err := os.Open(absInput)
	if err != nil {
		cleanup()
		return "", nil, fmt.Errorf("open encrypted backup: %w", err)
	}
	defer input.Close()
	candidatePath := filepath.Join(workspace, "candidate.db")
	candidate, err := os.OpenFile(candidatePath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		cleanup()
		return "", nil, fmt.Errorf("create restore candidate: %w", err)
	}
	if err := backupcrypto.Decrypt(ctx, candidate, input, key); err != nil {
		candidate.Close()
		cleanup()
		return "", nil, fmt.Errorf("decrypt backup: %w", err)
	}
	if err := candidate.Sync(); err != nil {
		candidate.Close()
		cleanup()
		return "", nil, fmt.Errorf("sync restore candidate: %w", err)
	}
	if err := candidate.Close(); err != nil {
		cleanup()
		return "", nil, fmt.Errorf("close restore candidate: %w", err)
	}
	if err := sqlite.PrepareRestore(ctx, candidatePath); err != nil {
		cleanup()
		return "", nil, fmt.Errorf("prepare restore candidate: %w", err)
	}
	return candidatePath, cleanup, nil
}

func acquireRestoreLock(path string) (*filelock.Lock, error) {
	lock, err := filelock.Acquire(path)
	if errors.Is(err, filelock.ErrLocked) {
		return nil, ErrDatabaseInUse
	}
	if err != nil {
		return nil, fmt.Errorf("acquire restore lock: %w", err)
	}
	return lock, nil
}

func replaceDatabase(databasePath, candidatePath string) (string, error) {
	existing := make([]string, 0, 3)
	for _, path := range databaseFiles(databasePath) {
		_, err := os.Stat(path)
		switch {
		case err == nil:
			existing = append(existing, path)
		case errors.Is(err, fs.ErrNotExist):
		default:
			return "", fmt.Errorf("inspect existing database file %q: %w", path, err)
		}
	}

	var preservedDirectory string
	if len(existing) > 0 {
		prefix := filepath.Base(databasePath) + ".pre-restore-" + time.Now().UTC().Format("20060102T150405Z") + "-"
		var err error
		preservedDirectory, err = os.MkdirTemp(filepath.Dir(databasePath), prefix)
		if err != nil {
			return "", fmt.Errorf("create preserved database directory: %w", err)
		}
		if err := os.Chmod(preservedDirectory, 0o700); err != nil {
			_ = os.Remove(preservedDirectory)
			return "", fmt.Errorf("restrict preserved database directory permissions: %w", err)
		}
	}

	moved := make([]movedFile, 0, len(existing))
	rollback := func() error {
		var rollbackErr error
		for index := len(moved) - 1; index >= 0; index-- {
			item := moved[index]
			if err := os.Rename(item.preserved, item.original); err != nil {
				rollbackErr = errors.Join(rollbackErr, fmt.Errorf("restore preserved file %q: %w", item.original, err))
			}
		}
		if preservedDirectory != "" {
			if err := os.Remove(preservedDirectory); err != nil && !errors.Is(err, fs.ErrNotExist) {
				rollbackErr = errors.Join(rollbackErr, fmt.Errorf("remove empty preserved database directory: %w", err))
			}
		}
		return rollbackErr
	}
	for _, original := range existing {
		preserved := filepath.Join(preservedDirectory, filepath.Base(original))
		if err := os.Rename(original, preserved); err != nil {
			rollbackErr := rollback()
			return "", errors.Join(fmt.Errorf("preserve database file %q: %w", original, err), rollbackErr)
		}
		moved = append(moved, movedFile{original: original, preserved: preserved})
	}

	if err := os.Rename(candidatePath, databasePath); err != nil {
		rollbackErr := rollback()
		return "", errors.Join(fmt.Errorf("install restored database: %w", err), rollbackErr)
	}
	return preservedDirectory, nil
}

type movedFile struct {
	original  string
	preserved string
}

func databaseFiles(path string) []string {
	return []string{path, path + "-wal", path + "-shm"}
}
