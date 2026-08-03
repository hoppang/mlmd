package autobackup

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"testing"
	"time"

	"github.com/hoppang/mlmd/server/internal/filelock"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

func TestRunCreatesOneBackupPerUTCDay(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	directory := t.TempDir()
	databasePath := filepath.Join(directory, "mlmd.db")
	store, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	options := Options{
		DatabasePath: databasePath,
		Directory:    filepath.Join(directory, "backups"),
		Key:          testKey(),
		Now:          time.Date(2026, 8, 3, 23, 30, 0, 0, time.FixedZone("KST", 9*60*60)),
	}

	first, err := Run(ctx, options)
	if err != nil {
		t.Fatal(err)
	}
	if !first.Created || filepath.Base(first.BackupPath) != "mlmd-auto-2026-08-03.mlmd-backup" {
		t.Fatalf("unexpected first result: %#v", first)
	}
	second, err := Run(ctx, options)
	if err != nil {
		t.Fatal(err)
	}
	if second.Created || second.BackupPath != first.BackupPath {
		t.Fatalf("same UTC day was backed up twice: %#v", second)
	}
}

func TestRunRefusesMaintenanceLockAndMissingDatabase(t *testing.T) {
	t.Parallel()
	directory := t.TempDir()
	databasePath := filepath.Join(directory, "mlmd.db")
	if _, err := Run(context.Background(), Options{
		DatabasePath: databasePath,
		Directory:    filepath.Join(directory, "backups"),
		Key:          testKey(),
		Now:          time.Now(),
	}); err == nil {
		t.Fatal("expected missing database to fail")
	}
	store, err := sqlite.Open(context.Background(), databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	lock, err := filelock.Acquire(databasePath + ".maintenance.lock")
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Release()
	_, err = Run(context.Background(), Options{
		DatabasePath: databasePath,
		Directory:    filepath.Join(directory, "backups"),
		Key:          testKey(),
		Now:          time.Now(),
	})
	if !errors.Is(err, filelock.ErrLocked) {
		t.Fatalf("expected maintenance lock error, got %v", err)
	}
}

func TestPruneKeepsSevenDailyAndEightWeeklyBackups(t *testing.T) {
	t.Parallel()
	directory := t.TempDir()
	now := time.Date(2026, 8, 5, 12, 0, 0, 0, time.UTC) // Wednesday.
	for daysAgo := 0; daysAgo < 80; daysAgo++ {
		date := now.AddDate(0, 0, -daysAgo)
		path := filepath.Join(directory, managedFilename(date))
		if err := os.WriteFile(path, []byte("backup"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	unmanaged := filepath.Join(directory, "manual-2026-01-01.mlmd-backup")
	if err := os.WriteFile(unmanaged, []byte("manual"), 0o600); err != nil {
		t.Fatal(err)
	}
	future := filepath.Join(directory, managedFilename(now.AddDate(0, 0, 2)))
	if err := os.WriteFile(future, []byte("future"), 0o600); err != nil {
		t.Fatal(err)
	}

	removed, err := Prune(directory, now)
	if err != nil {
		t.Fatal(err)
	}
	if len(removed) == 0 {
		t.Fatal("expected expired backups to be removed")
	}
	entries, err := os.ReadDir(directory)
	if err != nil {
		t.Fatal(err)
	}
	keptDates := make([]string, 0)
	for _, entry := range entries {
		if date, ok := parseManagedFilename(entry.Name()); ok && !date.After(dateOnly(now)) {
			keptDates = append(keptDates, date.Format(time.DateOnly))
		}
	}
	sort.Strings(keptDates)
	want := []string{
		"2026-06-21", "2026-06-28", "2026-07-05", "2026-07-12",
		"2026-07-19", "2026-07-26",
		"2026-07-30", "2026-07-31", "2026-08-01", "2026-08-02",
		"2026-08-03", "2026-08-04", "2026-08-05",
	}
	if len(keptDates) != len(want) {
		t.Fatalf("unexpected retained dates: %v", keptDates)
	}
	for index := range want {
		if keptDates[index] != want[index] {
			t.Fatalf("unexpected retained dates: %v", keptDates)
		}
	}
	for _, path := range []string{unmanaged, future} {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("protected file %q was removed: %v", path, err)
		}
	}
}

func testKey() []byte {
	key := make([]byte, 32)
	for index := range key {
		key[index] = byte(index + 1)
	}
	return key
}
