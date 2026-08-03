package migrations

import (
	"context"
	"database/sql"
	_ "embed"
)

//go:embed 001_initial.sql
var initialSchema string

func Apply(ctx context.Context, db *sql.DB) error {
	if _, err := db.ExecContext(ctx, initialSchema); err != nil {
		return err
	}
	return ensureInviteConsumedByDevice(ctx, db)
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
