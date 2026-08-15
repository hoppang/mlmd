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

func TestApplyMarksExistingInstallationBootstrapConsumed(t *testing.T) {
	databasePath := filepath.Join(t.TempDir(), "existing.db")
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(databasePath))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`
		INSERT INTO family_spaces(id, display_name, created_at, next_seq)
		VALUES ('space-id', 'Family', '2026-08-15T00:00:00Z', 0);
		INSERT INTO devices(id, family_space_id, token_hash, role, display_name, created_at)
		VALUES ('device-id', 'space-id', X'01', 'owner', 'Phone', '2026-08-15T00:00:00Z');
		DROP TABLE bootstrap_state;
		PRAGMA user_version = 1;
	`); err != nil {
		t.Fatal(err)
	}
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	var spaceID, deviceID string
	if err := db.QueryRow(`
		SELECT family_space_id, device_id
		FROM bootstrap_state WHERE singleton = 1`,
	).Scan(&spaceID, &deviceID); err != nil {
		t.Fatal(err)
	}
	if spaceID != "space-id" || deviceID != "device-id" {
		t.Fatalf("unexpected migrated bootstrap identity: %q %q", spaceID, deviceID)
	}
}

func TestApplyAddsSyncSnapshotsToExistingInstallation(t *testing.T) {
	databasePath := filepath.Join(t.TempDir(), "existing-v2.db")
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(databasePath))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`DROP TABLE sync_snapshots; PRAGMA user_version = 2;`); err != nil {
		t.Fatal(err)
	}
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	var found int
	if err := db.QueryRow(`
		SELECT 1 FROM sqlite_schema
		WHERE type = 'table' AND name = 'sync_snapshots'`,
	).Scan(&found); err != nil {
		t.Fatal(err)
	}
	var version int
	if err := db.QueryRow(`PRAGMA user_version`).Scan(&version); err != nil {
		t.Fatal(err)
	}
	if found != 1 || version != migrations.CurrentVersion {
		t.Fatalf("snapshot migration result: found=%d version=%d", found, version)
	}
}

func TestApplyAddsCompactedChangesToExistingInstallation(t *testing.T) {
	databasePath := filepath.Join(t.TempDir(), "existing-v3.db")
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(databasePath))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`DROP TABLE compacted_changes; PRAGMA user_version = 3;`); err != nil {
		t.Fatal(err)
	}
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	var found int
	if err := db.QueryRow(`
		SELECT 1 FROM sqlite_schema
		WHERE type = 'table' AND name = 'compacted_changes'`,
	).Scan(&found); err != nil {
		t.Fatal(err)
	}
	var version int
	if err := db.QueryRow(`PRAGMA user_version`).Scan(&version); err != nil {
		t.Fatal(err)
	}
	if found != 1 || version != migrations.CurrentVersion {
		t.Fatalf("compacted changes migration result: found=%d version=%d", found, version)
	}
}
