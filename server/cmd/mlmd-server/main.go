package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/hoppang/mlmd/server/internal/autobackup"
	"github.com/hoppang/mlmd/server/internal/backupstatus"
	"github.com/hoppang/mlmd/server/internal/filelock"
	"github.com/hoppang/mlmd/server/internal/httpapi"
	"github.com/hoppang/mlmd/server/internal/restore"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if len(os.Args) >= 2 {
		switch os.Args[1] {
		case "healthcheck":
			if len(os.Args) != 2 {
				logger.Error("healthcheck does not accept arguments")
				os.Exit(2)
			}
			if err := runHealthcheck(); err != nil {
				logger.Error("healthcheck failed", "error", err)
				os.Exit(1)
			}
			return
		case "backup":
			if err := runBackup(logger, os.Args[2:]); err != nil {
				logger.Error("backup failed", "error", err)
				os.Exit(1)
			}
			return
		case "backup-scheduler":
			if err := runBackupScheduler(logger, os.Args[2:]); err != nil {
				logger.Error("backup scheduler stopped", "error", err)
				os.Exit(1)
			}
			return
		case "restore":
			if err := runRestore(logger, os.Args[2:]); err != nil {
				logger.Error("restore failed", "error", err)
				os.Exit(1)
			}
			return
		case "verify-backup":
			if err := runVerifyBackup(logger, os.Args[2:]); err != nil {
				logger.Error("backup verification failed", "error", err)
				os.Exit(1)
			}
			return
		case "generate-backup-key":
			if err := runGenerateBackupKey(os.Args[2:]); err != nil {
				logger.Error("backup key generation failed", "error", err)
				os.Exit(1)
			}
			return
		}
	}
	if err := run(logger); err != nil {
		logger.Error("server stopped", "error", err)
		os.Exit(1)
	}
}

func runVerifyBackup(logger *slog.Logger, args []string) error {
	flags := flag.NewFlagSet("verify-backup", flag.ContinueOnError)
	input := flags.String("input", "", "path to the encrypted backup")
	keyFile := flags.String("key-file", "", "file containing a 32-byte base64url backup key")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *input == "" || flags.NArg() != 0 {
		return errors.New("usage: mlmd-server verify-backup --input <path> [--key-file <path>]")
	}
	backupKey, err := loadBackupKey(*keyFile)
	if err != nil {
		return err
	}
	defer clear(backupKey)
	verifyCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	databasePath := envOrDefault("MLMD_DATABASE_PATH", "data/mlmd.db")
	workspaceDirectory := filepath.Dir(databasePath)
	if err := restore.Verify(verifyCtx, *input, workspaceDirectory, backupKey); err != nil {
		return err
	}
	logger.Info("backup verification completed", "input", *input)
	return nil
}

func runBackupScheduler(logger *slog.Logger, args []string) error {
	flags := flag.NewFlagSet("backup-scheduler", flag.ContinueOnError)
	directory := flags.String("directory", "", "directory for managed encrypted backups")
	keyFile := flags.String("key-file", "", "file containing a 32-byte base64url backup key")
	interval := flags.Duration("interval", time.Hour, "interval for checking whether today's backup exists")
	once := flags.Bool("once", false, "run one backup and retention cycle, then exit")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *directory == "" || *interval <= 0 || flags.NArg() != 0 {
		return errors.New("usage: mlmd-server backup-scheduler --directory <path> [--key-file <path>] [--interval 1h] [--once]")
	}
	backupKey, err := loadBackupKey(*keyFile)
	if err != nil {
		return err
	}
	defer clear(backupKey)

	schedulerCtx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()
	databasePath := envOrDefault("MLMD_DATABASE_PATH", "data/mlmd.db")
	statusPath := databasePath + ".backup-status.json"
	cycle := func(ctx context.Context, now time.Time) (autobackup.Result, error) {
		return autobackup.Run(ctx, autobackup.Options{
			DatabasePath: databasePath,
			Directory:    *directory,
			Key:          backupKey,
			Now:          now,
		})
	}
	if *once {
		attemptAt := time.Now().UTC()
		result, err := cycle(schedulerCtx, attemptAt)
		nextAttemptAt := attemptAt.Add(*interval)
		if statusErr := recordBackupCycle(statusPath, attemptAt, &nextAttemptAt, result, err); statusErr != nil {
			logger.Error("record backup status failed", "error", statusErr)
		}
		if err != nil {
			return err
		}
		logScheduledBackupResult(logger, result)
		return nil
	}
	return backupSchedulerLoop(schedulerCtx, logger, *interval, statusPath, cycle)
}

type backupCycle func(context.Context, time.Time) (autobackup.Result, error)

func backupSchedulerLoop(ctx context.Context, logger *slog.Logger, interval time.Duration, statusPath string, cycle backupCycle) error {
	for {
		attemptAt := time.Now().UTC()
		result, err := cycle(ctx, attemptAt)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
		}
		nextAttemptAt := attemptAt.Add(interval)
		if statusErr := recordBackupCycle(statusPath, attemptAt, &nextAttemptAt, result, err); statusErr != nil {
			logger.Error("record backup status failed", "error", statusErr)
		}
		if err == nil {
			logScheduledBackupResult(logger, result)
		} else {
			logger.Error("scheduled backup cycle failed", "error", err)
		}
		timer := time.NewTimer(interval)
		select {
		case <-ctx.Done():
			timer.Stop()
			return nil
		case <-timer.C:
		}
	}
}

func recordBackupCycle(statusPath string, attemptAt time.Time, nextAttemptAt *time.Time, result autobackup.Result, cycleErr error) error {
	if cycleErr != nil {
		return backupstatus.RecordFailure(statusPath, attemptAt, nextAttemptAt)
	}
	return backupstatus.RecordSuccess(statusPath, backupstatus.Success{
		AttemptAt:     attemptAt,
		BackupAt:      result.BackupTime,
		BackupPath:    result.BackupPath,
		NextAttemptAt: nextAttemptAt,
	})
}

func logScheduledBackupResult(logger *slog.Logger, result autobackup.Result) {
	message := "scheduled backup already exists"
	if result.Created {
		message = "scheduled backup completed"
	}
	logger.Info(
		message,
		"output", result.BackupPath,
		"expired_backups_removed", len(result.RemovedPaths),
	)
}

func runRestore(logger *slog.Logger, args []string) error {
	flags := flag.NewFlagSet("restore", flag.ContinueOnError)
	input := flags.String("input", "", "path to the encrypted backup")
	keyFile := flags.String("key-file", "", "file containing a 32-byte base64url backup key")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *input == "" || flags.NArg() != 0 {
		return errors.New("usage: mlmd-server restore --input <path> [--key-file <path>]")
	}
	backupKey, err := loadBackupKey(*keyFile)
	if err != nil {
		return err
	}
	defer clear(backupKey)

	restoreCtx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()
	databasePath := envOrDefault("MLMD_DATABASE_PATH", "data/mlmd.db")
	result, err := restore.Database(restoreCtx, *input, databasePath, backupKey)
	if err != nil {
		return err
	}
	logger.Info(
		"restore completed",
		"database", databasePath,
		"input", *input,
		"preserved_database_directory", result.PreservedDirectory,
	)
	return nil
}

func runGenerateBackupKey(args []string) error {
	flags := flag.NewFlagSet("generate-backup-key", flag.ContinueOnError)
	output := flags.String("output", "", "path for the new backup key file")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *output == "" || flags.NArg() != 0 {
		return errors.New("usage: mlmd-server generate-backup-key --output <path>")
	}
	absOutput, err := filepath.Abs(*output)
	if err != nil {
		return fmt.Errorf("resolve backup key path: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(absOutput), 0o700); err != nil {
		return fmt.Errorf("create backup key directory: %w", err)
	}
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return fmt.Errorf("generate backup key: %w", err)
	}
	defer clear(key)
	encoded := base64.RawURLEncoding.EncodeToString(key)
	keyFile, err := os.OpenFile(absOutput, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return fmt.Errorf("create backup key file: %w", err)
	}
	completed := false
	defer func() {
		if !completed {
			_ = keyFile.Close()
			_ = os.Remove(absOutput)
		}
	}()
	if _, err := keyFile.WriteString(encoded); err != nil {
		return fmt.Errorf("write backup key file: %w", err)
	}
	if err := keyFile.Sync(); err != nil {
		return fmt.Errorf("sync backup key file: %w", err)
	}
	if err := keyFile.Close(); err != nil {
		return fmt.Errorf("close backup key file: %w", err)
	}
	completed = true
	return nil
}

func runBackup(logger *slog.Logger, args []string) error {
	flags := flag.NewFlagSet("backup", flag.ContinueOnError)
	output := flags.String("output", "", "path for the encrypted backup")
	keyFile := flags.String("key-file", "", "file containing a 32-byte base64url backup key")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *output == "" || flags.NArg() != 0 {
		return errors.New("usage: mlmd-server backup --output <path> [--key-file <path>]")
	}
	backupKey, err := loadBackupKey(*keyFile)
	if err != nil {
		return err
	}
	defer clear(backupKey)

	databasePath := envOrDefault("MLMD_DATABASE_PATH", "data/mlmd.db")
	if err := os.MkdirAll(filepath.Dir(databasePath), 0o700); err != nil {
		return err
	}
	backupCtx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()
	maintenanceLock, err := filelock.AcquireShared(databasePath + ".maintenance.lock")
	if err != nil {
		return fmt.Errorf("acquire backup maintenance lock: %w", err)
	}
	defer maintenanceLock.Release()
	serverStore, err := sqlite.Open(backupCtx, databasePath)
	if err != nil {
		return err
	}
	defer serverStore.Close()
	if err := serverStore.BackupEncrypted(backupCtx, *output, backupKey); err != nil {
		return err
	}
	logger.Info("backup completed", "database", databasePath, "output", *output)
	return nil
}

func loadBackupKey(keyFile string) ([]byte, error) {
	environmentKey := os.Getenv("MLMD_BACKUP_KEY")
	if keyFile != "" && environmentKey != "" {
		return nil, errors.New("set either --key-file or MLMD_BACKUP_KEY, not both")
	}
	encoded := environmentKey
	if keyFile != "" {
		contents, err := os.ReadFile(keyFile)
		if err != nil {
			return nil, fmt.Errorf("read backup key file: %w", err)
		}
		encoded = string(contents)
	}
	encoded = strings.TrimSpace(encoded)
	if encoded == "" {
		return nil, errors.New("backup encryption key is required via --key-file or MLMD_BACKUP_KEY")
	}
	key, err := base64.RawURLEncoding.Strict().DecodeString(encoded)
	if err != nil || len(key) != 32 {
		return nil, errors.New("backup key must be 32 bytes encoded as unpadded base64url")
	}
	return key, nil
}

func runHealthcheck() error {
	client := &http.Client{Timeout: 2 * time.Second}
	request, err := http.NewRequest(http.MethodGet, "http://127.0.0.1:8080/v1/health/ready", nil)
	if err != nil {
		return err
	}
	response, err := client.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return errors.New("readiness endpoint returned " + response.Status)
	}
	return nil
}

func run(logger *slog.Logger) error {
	listenAddr := envOrDefault("MLMD_LISTEN_ADDR", "127.0.0.1:8080")
	databasePath := envOrDefault("MLMD_DATABASE_PATH", "data/mlmd.db")
	bootstrapToken := os.Getenv("MLMD_BOOTSTRAP_TOKEN")
	if len(bootstrapToken) < 32 {
		return errors.New("MLMD_BOOTSTRAP_TOKEN must contain at least 32 characters")
	}
	if err := os.MkdirAll(filepath.Dir(databasePath), 0o700); err != nil {
		return err
	}

	rootCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	serverLock, err := filelock.Acquire(databasePath + ".server.lock")
	if err != nil {
		return fmt.Errorf("acquire database server lock: %w", err)
	}
	defer serverLock.Release()
	serverStore, err := sqlite.Open(rootCtx, databasePath)
	if err != nil {
		return err
	}
	defer serverStore.Close()

	httpServer := &http.Server{
		Addr:              listenAddr,
		Handler:           httpapi.New(serverStore, bootstrapToken, logger, databasePath+".backup-status.json").Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    16 * 1024,
	}
	errCh := make(chan error, 1)
	go func() {
		logger.Info("server listening", "address", listenAddr)
		errCh <- httpServer.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-rootCtx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := httpServer.Shutdown(shutdownCtx); err != nil {
			return err
		}
		return nil
	}
}

func envOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
