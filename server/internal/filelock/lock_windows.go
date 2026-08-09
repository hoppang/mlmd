//go:build windows

package filelock

import (
	"errors"
	"fmt"
	"os"

	"golang.org/x/sys/windows"
)

func lockFile(file *os.File, exclusive bool) error {
	var overlapped windows.Overlapped
	flags := uint32(windows.LOCKFILE_FAIL_IMMEDIATELY)
	if exclusive {
		flags |= windows.LOCKFILE_EXCLUSIVE_LOCK
	}
	err := windows.LockFileEx(
		windows.Handle(file.Fd()),
		flags,
		0,
		1,
		0,
		&overlapped,
	)
	if errors.Is(err, windows.ERROR_LOCK_VIOLATION) {
		return ErrLocked
	}
	if err != nil {
		return fmt.Errorf("acquire file lock: %w", err)
	}
	return nil
}

func unlockFile(file *os.File) error {
	var overlapped windows.Overlapped
	if err := windows.UnlockFileEx(
		windows.Handle(file.Fd()),
		0,
		1,
		0,
		&overlapped,
	); err != nil {
		return fmt.Errorf("release file lock: %w", err)
	}
	return nil
}
