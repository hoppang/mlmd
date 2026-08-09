package autobackup

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/hoppang/mlmd/server/internal/filelock"
	"github.com/hoppang/mlmd/server/internal/restore"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

const (
	filenamePrefix = "mlmd-auto-"
	filenameSuffix = ".mlmd-backup"
)

type Options struct {
	DatabasePath string
	Directory    string
	Key          []byte
	Now          time.Time
}

type Result struct {
	BackupPath   string
	BackupTime   time.Time
	Created      bool
	RemovedPaths []string
}

// Run creates at most one managed backup per UTC day, then applies the
// seven-daily/eight-weekly retention policy to managed backup files only.
func Run(ctx context.Context, options Options) (Result, error) {
	if len(options.Key) != 32 {
		return Result{}, errors.New("automatic backup key must be exactly 32 bytes")
	}
	if options.DatabasePath == "" {
		return Result{}, errors.New("automatic backup database path is required")
	}
	if options.Directory == "" {
		return Result{}, errors.New("automatic backup directory is required")
	}
	now := options.Now.UTC()
	if now.IsZero() {
		now = time.Now().UTC()
	}
	absDatabase, err := filepath.Abs(options.DatabasePath)
	if err != nil {
		return Result{}, fmt.Errorf("resolve automatic backup database path: %w", err)
	}
	if info, err := os.Stat(absDatabase); err != nil {
		return Result{}, fmt.Errorf("inspect automatic backup database: %w", err)
	} else if !info.Mode().IsRegular() {
		return Result{}, errors.New("automatic backup database is not a regular file")
	}
	absDirectory, err := filepath.Abs(options.Directory)
	if err != nil {
		return Result{}, fmt.Errorf("resolve automatic backup directory: %w", err)
	}
	if err := os.MkdirAll(absDirectory, 0o700); err != nil {
		return Result{}, fmt.Errorf("create automatic backup directory: %w", err)
	}
	backupPath := filepath.Join(absDirectory, managedFilename(now))
	created, backupTime, err := createBackup(ctx, absDatabase, backupPath, options.Key)
	if err != nil {
		return Result{}, err
	}
	removed, err := Prune(absDirectory, now)
	if err != nil {
		return Result{BackupPath: backupPath, BackupTime: backupTime, Created: created}, err
	}
	return Result{BackupPath: backupPath, BackupTime: backupTime, Created: created, RemovedPaths: removed}, nil
}

func createBackup(ctx context.Context, databasePath, backupPath string, key []byte) (bool, time.Time, error) {
	info, err := os.Stat(backupPath)
	if err == nil {
		if !info.Mode().IsRegular() {
			return false, time.Time{}, errors.New("automatic backup destination exists and is not a regular file")
		}
		if _, markerErr := os.Stat(unverifiedMarker(backupPath)); markerErr == nil {
			maintenanceLock, lockErr := filelock.Acquire(databasePath + ".maintenance.lock")
			if lockErr != nil {
				return false, time.Time{}, fmt.Errorf("acquire automatic backup verification lock: %w", lockErr)
			}
			defer maintenanceLock.Release()
			if verifyErr := restore.Verify(ctx, backupPath, filepath.Dir(databasePath), key); verifyErr != nil {
				cleanupErr := discardUnverifiedBackup(backupPath)
				return false, time.Time{}, errors.Join(
					fmt.Errorf("verify previously unverified automatic backup: %w", verifyErr),
					cleanupErr,
				)
			}
			if removeErr := os.Remove(unverifiedMarker(backupPath)); removeErr != nil && !errors.Is(removeErr, fs.ErrNotExist) {
				return false, time.Time{}, fmt.Errorf("clear automatic backup verification marker: %w", removeErr)
			}
		} else if !errors.Is(markerErr, fs.ErrNotExist) {
			return false, time.Time{}, fmt.Errorf("inspect automatic backup verification marker: %w", markerErr)
		}
		return false, info.ModTime().UTC(), nil
	}
	if !errors.Is(err, fs.ErrNotExist) {
		return false, time.Time{}, fmt.Errorf("inspect automatic backup destination: %w", err)
	}
	maintenanceLock, err := filelock.Acquire(databasePath + ".maintenance.lock")
	if err != nil {
		return false, time.Time{}, fmt.Errorf("acquire automatic backup maintenance lock: %w", err)
	}
	defer maintenanceLock.Release()
	if err := markUnverified(backupPath); err != nil {
		return false, time.Time{}, err
	}
	store, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		_ = os.Remove(unverifiedMarker(backupPath))
		return false, time.Time{}, err
	}
	if err := store.BackupEncrypted(ctx, backupPath, key); err != nil {
		store.Close()
		_ = os.Remove(unverifiedMarker(backupPath))
		return false, time.Time{}, err
	}
	if err := store.Close(); err != nil {
		return false, time.Time{}, fmt.Errorf("close automatic backup database: %w", err)
	}
	if err := restore.Verify(ctx, backupPath, filepath.Dir(databasePath), key); err != nil {
		cleanupErr := discardUnverifiedBackup(backupPath)
		return false, time.Time{}, errors.Join(fmt.Errorf("verify automatic backup: %w", err), cleanupErr)
	}
	if err := os.Remove(unverifiedMarker(backupPath)); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return false, time.Time{}, fmt.Errorf("clear automatic backup verification marker: %w", err)
	}
	info, err = os.Stat(backupPath)
	if err != nil {
		return false, time.Time{}, fmt.Errorf("inspect verified automatic backup: %w", err)
	}
	return true, info.ModTime().UTC(), nil
}

// Prune removes only files matching the managed filename format. It retains
// every backup from the latest seven UTC dates and the newest backup in each
// of the current and previous seven ISO weeks. Future-dated files are kept.
func Prune(directory string, now time.Time) ([]string, error) {
	absDirectory, err := filepath.Abs(directory)
	if err != nil {
		return nil, fmt.Errorf("resolve automatic backup directory: %w", err)
	}
	entries, err := os.ReadDir(absDirectory)
	if err != nil {
		return nil, fmt.Errorf("read automatic backup directory: %w", err)
	}
	today := dateOnly(now.UTC())
	dailyCutoff := today.AddDate(0, 0, -6)
	currentWeek := isoWeekStart(today)
	weeklyCutoff := currentWeek.AddDate(0, 0, -49)

	managed := make([]managedFile, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			return nil, fmt.Errorf("inspect automatic backup entry %q: %w", entry.Name(), err)
		}
		if !info.Mode().IsRegular() {
			continue
		}
		date, ok := parseManagedFilename(entry.Name())
		if !ok {
			continue
		}
		managed = append(managed, managedFile{
			path: filepath.Join(absDirectory, entry.Name()),
			date: date,
		})
	}
	sort.Slice(managed, func(i, j int) bool {
		if managed[i].date.Equal(managed[j].date) {
			return managed[i].path > managed[j].path
		}
		return managed[i].date.After(managed[j].date)
	})

	keep := make(map[string]bool, len(managed))
	weekly := make(map[time.Time]bool, 8)
	for _, file := range managed {
		if file.date.After(today) {
			keep[file.path] = true
			continue
		}
		if !file.date.Before(dailyCutoff) {
			keep[file.path] = true
		}
		week := isoWeekStart(file.date)
		if !week.Before(weeklyCutoff) && !week.After(currentWeek) && !weekly[week] {
			weekly[week] = true
			keep[file.path] = true
		}
	}

	removed := make([]string, 0)
	for _, file := range managed {
		if keep[file.path] {
			continue
		}
		if err := os.Remove(file.path); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return removed, fmt.Errorf("remove expired automatic backup %q: %w", file.path, err)
		}
		if err := os.Remove(unverifiedMarker(file.path)); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return removed, fmt.Errorf("remove expired automatic backup verification marker %q: %w", file.path, err)
		}
		removed = append(removed, file.path)
	}
	return removed, nil
}

type managedFile struct {
	path string
	date time.Time
}

func managedFilename(value time.Time) string {
	return filenamePrefix + value.UTC().Format(time.DateOnly) + filenameSuffix
}

func parseManagedFilename(name string) (time.Time, bool) {
	if !strings.HasPrefix(name, filenamePrefix) || !strings.HasSuffix(name, filenameSuffix) {
		return time.Time{}, false
	}
	dateText := strings.TrimSuffix(strings.TrimPrefix(name, filenamePrefix), filenameSuffix)
	date, err := time.Parse(time.DateOnly, dateText)
	if err != nil || managedFilename(date) != name {
		return time.Time{}, false
	}
	return date, true
}

func dateOnly(value time.Time) time.Time {
	year, month, day := value.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
}

func isoWeekStart(value time.Time) time.Time {
	weekday := (int(value.Weekday()) + 6) % 7
	return dateOnly(value).AddDate(0, 0, -weekday)
}

func unverifiedMarker(backupPath string) string {
	return backupPath + ".unverified"
}

func markUnverified(backupPath string) error {
	marker, err := os.OpenFile(unverifiedMarker(backupPath), os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o600)
	if err != nil {
		return fmt.Errorf("create automatic backup verification marker: %w", err)
	}
	if err := marker.Chmod(0o600); err != nil {
		marker.Close()
		return fmt.Errorf("restrict automatic backup verification marker: %w", err)
	}
	if err := marker.Sync(); err != nil {
		marker.Close()
		return fmt.Errorf("sync automatic backup verification marker: %w", err)
	}
	if err := marker.Close(); err != nil {
		return fmt.Errorf("close automatic backup verification marker: %w", err)
	}
	return nil
}

func discardUnverifiedBackup(backupPath string) error {
	removeErr := os.Remove(backupPath)
	if removeErr != nil && !errors.Is(removeErr, fs.ErrNotExist) {
		return removeErr
	}
	markerErr := os.Remove(unverifiedMarker(backupPath))
	if errors.Is(markerErr, fs.ErrNotExist) {
		return nil
	}
	return markerErr
}
