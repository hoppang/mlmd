package filelock

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

var ErrLocked = errors.New("file is locked by another process")

type Lock struct {
	mu       sync.Mutex
	file     *os.File
	released bool
}

func Acquire(path string) (*Lock, error) {
	return acquire(path, true)
}

func AcquireShared(path string) (*Lock, error) {
	return acquire(path, false)
}

func acquire(path string, exclusive bool) (*Lock, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("resolve lock path: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(absPath), 0o700); err != nil {
		return nil, fmt.Errorf("create lock directory: %w", err)
	}
	file, err := os.OpenFile(absPath, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open lock file: %w", err)
	}
	if err := lockFile(file, exclusive); err != nil {
		file.Close()
		return nil, err
	}
	return &Lock{file: file}, nil
}

func (l *Lock) Release() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.released {
		return nil
	}
	l.released = true
	unlockErr := unlockFile(l.file)
	closeErr := l.file.Close()
	if unlockErr != nil {
		return unlockErr
	}
	return closeErr
}
