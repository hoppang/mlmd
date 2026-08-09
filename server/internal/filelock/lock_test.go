package filelock_test

import (
	"errors"
	"path/filepath"
	"testing"

	"github.com/hoppang/mlmd/server/internal/filelock"
)

func TestExclusiveLockIsReleased(t *testing.T) {
	path := filepath.Join(t.TempDir(), "database.lock")
	first, err := filelock.Acquire(path)
	if err != nil {
		t.Fatal(err)
	}
	second, err := filelock.Acquire(path)
	if !errors.Is(err, filelock.ErrLocked) {
		if second != nil {
			second.Release()
		}
		first.Release()
		t.Fatalf("expected second lock to fail, got %v", err)
	}
	if err := first.Release(); err != nil {
		t.Fatal(err)
	}
	if err := first.Release(); err != nil {
		t.Fatalf("release should be idempotent: %v", err)
	}
	third, err := filelock.Acquire(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := third.Release(); err != nil {
		t.Fatal(err)
	}
}

func TestSharedLocksExcludeWriter(t *testing.T) {
	path := filepath.Join(t.TempDir(), "maintenance.lock")
	first, err := filelock.AcquireShared(path)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Release()
	second, err := filelock.AcquireShared(path)
	if err != nil {
		t.Fatal(err)
	}
	defer second.Release()
	exclusive, err := filelock.Acquire(path)
	if !errors.Is(err, filelock.ErrLocked) {
		if exclusive != nil {
			exclusive.Release()
		}
		t.Fatalf("expected exclusive lock to fail, got %v", err)
	}
}
