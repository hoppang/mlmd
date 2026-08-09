package migrations_test

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"

	"github.com/hoppang/mlmd/server/migrations"
	_ "modernc.org/sqlite"
)

func TestApplyRejectsNewerSchemaVersion(t *testing.T) {
	databasePath := filepath.Join(t.TempDir(), "future.db")
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(databasePath))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if _, err := db.Exec(`PRAGMA user_version = 999`); err != nil {
		t.Fatal(err)
	}
	if err := migrations.Apply(context.Background(), db); err == nil {
		t.Fatal("expected a newer schema version to be rejected")
	}
	var version int
	if err := db.QueryRow(`PRAGMA user_version`).Scan(&version); err != nil {
		t.Fatal(err)
	}
	if version != 999 {
		t.Fatalf("newer schema version was modified: %d", version)
	}
}
