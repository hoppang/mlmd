package backupstatus

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"time"

	"github.com/hoppang/mlmd/server/internal/filelock"
)

const (
	CurrentVersion = 1
	StateHealthy   = "healthy"
	StateDegraded  = "degraded"
	StateUnknown   = "unknown"
	maxStatusBytes = 64 * 1024
)

type Status struct {
	Version             int        `json:"version"`
	State               string     `json:"state"`
	LastAttemptAt       *time.Time `json:"lastAttemptAt,omitempty"`
	LastSuccessAt       *time.Time `json:"lastSuccessAt,omitempty"`
	LastBackupFile      string     `json:"lastBackupFile,omitempty"`
	ConsecutiveFailures int        `json:"consecutiveFailures"`
	NextAttemptAt       *time.Time `json:"nextAttemptAt,omitempty"`
	ErrorCode           string     `json:"errorCode,omitempty"`
}

type Success struct {
	AttemptAt     time.Time
	BackupAt      time.Time
	BackupPath    string
	NextAttemptAt *time.Time
}

func RecordSuccess(path string, success Success) error {
	if success.AttemptAt.IsZero() || success.BackupAt.IsZero() || success.BackupPath == "" {
		return errors.New("complete backup success status is required")
	}
	return update(path, func(previous Status) Status {
		attemptAt := success.AttemptAt.UTC()
		backupAt := success.BackupAt.UTC()
		return Status{
			Version:        CurrentVersion,
			State:          StateHealthy,
			LastAttemptAt:  &attemptAt,
			LastSuccessAt:  &backupAt,
			LastBackupFile: filepath.Base(success.BackupPath),
			NextAttemptAt:  utcPointer(success.NextAttemptAt),
		}
	})
}

func RecordFailure(path string, attemptAt time.Time, nextAttemptAt *time.Time) error {
	if attemptAt.IsZero() {
		return errors.New("backup failure attempt time is required")
	}
	return update(path, func(previous Status) Status {
		attempt := attemptAt.UTC()
		previous.Version = CurrentVersion
		previous.State = StateDegraded
		previous.LastAttemptAt = &attempt
		previous.ConsecutiveFailures++
		previous.NextAttemptAt = utcPointer(nextAttemptAt)
		previous.ErrorCode = "backup_cycle_failed"
		return previous
	})
}

func Read(path string) (Status, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return Status{}, fmt.Errorf("resolve backup status path: %w", err)
	}
	info, err := os.Stat(absPath)
	if err != nil {
		return Status{}, err
	}
	if !info.Mode().IsRegular() || info.Size() > maxStatusBytes {
		return Status{}, errors.New("backup status file is not a bounded regular file")
	}
	contents, err := os.ReadFile(absPath)
	if err != nil {
		return Status{}, err
	}
	var status Status
	if err := json.Unmarshal(contents, &status); err != nil {
		return Status{}, fmt.Errorf("decode backup status: %w", err)
	}
	if status.Version != CurrentVersion {
		return Status{}, fmt.Errorf("unsupported backup status version %d", status.Version)
	}
	if status.State != StateHealthy && status.State != StateDegraded {
		return Status{}, fmt.Errorf("invalid backup state %q", status.State)
	}
	return status, nil
}

// Evaluate marks a scheduler overdue after half of its previous interval has
// elapsed beyond the promised next attempt, with a minimum one-minute grace.
func Evaluate(status Status, now time.Time) Status {
	if status.NextAttemptAt == nil || status.LastAttemptAt == nil {
		return status
	}
	interval := status.NextAttemptAt.Sub(*status.LastAttemptAt)
	grace := interval / 2
	if grace < time.Minute {
		grace = time.Minute
	}
	if now.UTC().After(status.NextAttemptAt.Add(grace)) {
		status.State = StateDegraded
		status.ErrorCode = "backup_scheduler_overdue"
	}
	return status
}

func Unknown(errorCode string) Status {
	return Status{Version: CurrentVersion, State: StateUnknown, ErrorCode: errorCode}
}

func update(path string, transform func(Status) Status) error {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return fmt.Errorf("resolve backup status path: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(absPath), 0o700); err != nil {
		return fmt.Errorf("create backup status directory: %w", err)
	}
	lock, err := filelock.Acquire(absPath + ".lock")
	if err != nil {
		return fmt.Errorf("acquire backup status lock: %w", err)
	}
	defer lock.Release()
	previous, err := Read(absPath)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		previous = Status{Version: CurrentVersion, State: StateUnknown}
	}
	status := transform(previous)
	encoded, err := json.Marshal(status)
	if err != nil {
		return fmt.Errorf("encode backup status: %w", err)
	}
	temporary, err := os.CreateTemp(filepath.Dir(absPath), ".mlmd-backup-status-*")
	if err != nil {
		return fmt.Errorf("create temporary backup status: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("restrict backup status permissions: %w", err)
	}
	if _, err := temporary.Write(encoded); err != nil {
		temporary.Close()
		return fmt.Errorf("write backup status: %w", err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return fmt.Errorf("sync backup status: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close backup status: %w", err)
	}
	if err := replaceFile(temporaryPath, absPath); err != nil {
		return fmt.Errorf("publish backup status: %w", err)
	}
	return nil
}

func utcPointer(value *time.Time) *time.Time {
	if value == nil {
		return nil
	}
	utc := value.UTC()
	return &utc
}
