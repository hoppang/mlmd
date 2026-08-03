package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/hoppang/mlmd/server/internal/httpapi"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if len(os.Args) == 2 && os.Args[1] == "healthcheck" {
		if err := runHealthcheck(); err != nil {
			logger.Error("healthcheck failed", "error", err)
			os.Exit(1)
		}
		return
	}
	if err := run(logger); err != nil {
		logger.Error("server stopped", "error", err)
		os.Exit(1)
	}
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
	serverStore, err := sqlite.Open(rootCtx, databasePath)
	if err != nil {
		return err
	}
	defer serverStore.Close()

	httpServer := &http.Server{
		Addr:              listenAddr,
		Handler:           httpapi.New(serverStore, bootstrapToken, logger).Handler(),
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
