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
	created, err := createBackup(ctx, absDatabase, backupPath, options.Key)
	if err != nil {
		return Result{}, err
	}
	removed, err := Prune(absDirectory, now)
	if err != nil {
		return Result{BackupPath: backupPath, Created: created}, err
	}
	return Result{BackupPath: backupPath, Created: created, RemovedPaths: removed}, nil
}

func createBackup(ctx context.Context, databasePath, backupPath string, key []byte) (bool, error) {
	info, err := os.Stat(backupPath)
	if err == nil {
		if !info.Mode().IsRegular() {
			return false, errors.New("automatic backup destination exists and is not a regular file")
		}
		return false, nil
	}
	if !errors.Is(err, fs.ErrNotExist) {
		return false, fmt.Errorf("inspect automatic backup destination: %w", err)
	}
	maintenanceLock, err := filelock.Acquire(databasePath + ".maintenance.lock")
	if err != nil {
		return false, fmt.Errorf("acquire automatic backup maintenance lock: %w", err)
	}
	defer maintenanceLock.Release()
	store, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		return false, err
	}
	if err := store.BackupEncrypted(ctx, backupPath, key); err != nil {
		store.Close()
		return false, err
	}
	if err := store.Close(); err != nil {
		return false, fmt.Errorf("close automatic backup database: %w", err)
	}
	return true, nil
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
