package backupstatus_test

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/hoppang/mlmd/server/internal/backupstatus"
)

func TestRecordSuccessAndFailurePreserveUsefulState(t *testing.T) {
	t.Parallel()
	statusPath := filepath.Join(t.TempDir(), "backup-status.json")
	attempt := time.Date(2026, 8, 3, 1, 0, 0, 0, time.UTC)
	backupAt := attempt.Add(-time.Minute)
	next := attempt.Add(time.Hour)
	if err := backupstatus.RecordSuccess(statusPath, backupstatus.Success{
		AttemptAt: attempt, BackupAt: backupAt,
		BackupPath: filepath.Join("private", "mlmd-auto-2026-08-03.mlmd-backup"), NextAttemptAt: &next,
	}); err != nil {
		t.Fatal(err)
	}
	status, err := backupstatus.Read(statusPath)
	if err != nil {
		t.Fatal(err)
	}
	if status.State != backupstatus.StateHealthy || status.LastBackupFile != "mlmd-auto-2026-08-03.mlmd-backup" {
		t.Fatalf("unexpected success status: %#v", status)
	}
	failureAt := next
	afterFailure := failureAt.Add(time.Hour)
	if err := backupstatus.RecordFailure(statusPath, failureAt, &afterFailure); err != nil {
		t.Fatal(err)
	}
	status, err = backupstatus.Read(statusPath)
	if err != nil {
		t.Fatal(err)
	}
	if status.State != backupstatus.StateDegraded || status.ConsecutiveFailures != 1 ||
		status.LastSuccessAt == nil || !status.LastSuccessAt.Equal(backupAt) ||
		status.ErrorCode != "backup_cycle_failed" {
		t.Fatalf("unexpected failure status: %#v", status)
	}
}

func TestEvaluateMarksOverdueSchedulerDegraded(t *testing.T) {
	t.Parallel()
	attempt := time.Date(2026, 8, 3, 1, 0, 0, 0, time.UTC)
	next := attempt.Add(time.Hour)
	status := backupstatus.Status{
		Version:       backupstatus.CurrentVersion,
		State:         backupstatus.StateHealthy,
		LastAttemptAt: &attempt,
		NextAttemptAt: &next,
	}
	withinGrace := backupstatus.Evaluate(status, next.Add(29*time.Minute))
	if withinGrace.State != backupstatus.StateHealthy {
		t.Fatalf("scheduler degraded before grace elapsed: %#v", withinGrace)
	}
	overdue := backupstatus.Evaluate(status, next.Add(31*time.Minute))
	if overdue.State != backupstatus.StateDegraded || overdue.ErrorCode != "backup_scheduler_overdue" {
		t.Fatalf("overdue scheduler was not degraded: %#v", overdue)
	}
}
