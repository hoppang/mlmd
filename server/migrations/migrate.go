package migrations

import (
	"context"
	"database/sql"
	_ "embed"
	"fmt"
)

//go:embed 001_initial.sql
var initialSchema string

//go:embed 002_bootstrap_state.sql
var bootstrapStateSchema string

//go:embed 003_sync_snapshots.sql
var syncSnapshotsSchema string

const CurrentVersion = 3

func Apply(ctx context.Context, db *sql.DB) error {
	var version int
	if err := db.QueryRowContext(ctx, `PRAGMA user_version`).Scan(&version); err != nil {
		return err
	}
	if version > CurrentVersion {
		return fmt.Errorf("database schema version %d is newer than supported version %d", version, CurrentVersion)
	}
	if _, err := db.ExecContext(ctx, initialSchema); err != nil {
		return err
	}
	if err := ensureInviteConsumedByDevice(ctx, db); err != nil {
		return err
	}
	if _, err := db.ExecContext(ctx, bootstrapStateSchema); err != nil {
		return err
	}
	if _, err := db.ExecContext(ctx, syncSnapshotsSchema); err != nil {
		return err
	}
	_, err := db.ExecContext(ctx, fmt.Sprintf(`PRAGMA user_version = %d`, CurrentVersion))
	return err
}

func ensureInviteConsumedByDevice(ctx context.Context, db *sql.DB) error {
	rows, err := db.QueryContext(ctx, `PRAGMA table_info(invites)`)
	if err != nil {
		return err
	}
	found := false
	for rows.Next() {
		var cid, notNull, primaryKey int
		var name, columnType string
		var defaultValue any
		if err := rows.Scan(&cid, &name, &columnType, &notNull, &defaultValue, &primaryKey); err != nil {
			rows.Close()
			return err
		}
		if name == "consumed_by_device_id" {
			found = true
		}
	}
	if err := rows.Close(); err != nil {
		return err
	}
	if err := rows.Err(); err != nil {
		return err
	}
	if found {
		return nil
	}
	_, err = db.ExecContext(ctx, `ALTER TABLE invites ADD COLUMN consumed_by_device_id TEXT`)
	return err
}
