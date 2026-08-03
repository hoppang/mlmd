package sqlite

import (
	"context"
	"crypto/subtle"
	"database/sql"
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"github.com/hoppang/mlmd/server/internal/id"
	"github.com/hoppang/mlmd/server/internal/model"
	storepkg "github.com/hoppang/mlmd/server/internal/store"
	"github.com/hoppang/mlmd/server/migrations"
	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

func Open(ctx context.Context, path string) (*Store, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("resolve database path: %w", err)
	}
	dsn := "file:" + filepath.ToSlash(absPath) + "?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}
	// SQLite is the serialization boundary for this first home-server version.
	// One connection also keeps PRAGMA behavior predictable across requests.
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	if err := migrations.Apply(ctx, db); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("apply migrations: %w", err)
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) Ready(ctx context.Context) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	_, err = tx.ExecContext(ctx, `UPDATE readiness_probe SET checked_at = ? WHERE singleton = 1`, formatTime(time.Now()))
	return err
}

func (s *Store) CreateSpace(ctx context.Context, displayName, spaceID, deviceID, deviceDisplayName string, tokenHash []byte) (model.Space, model.Device, error) {
	now := time.Now().UTC()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return model.Space{}, model.Device{}, err
	}
	defer tx.Rollback()
	var existingDisplayName, existingCreatedAt string
	err = tx.QueryRowContext(ctx, `
		SELECT display_name, created_at FROM family_spaces WHERE id = ?`, spaceID,
	).Scan(&existingDisplayName, &existingCreatedAt)
	if err == nil {
		device, storedTokenHash, deviceErr := deviceForInviteRetry(ctx, tx, spaceID, deviceID)
		if deviceErr == nil && subtle.ConstantTimeCompare(storedTokenHash, tokenHash) == 1 {
			createdAt, parseErr := time.Parse(time.RFC3339Nano, existingCreatedAt)
			if parseErr != nil {
				return model.Space{}, model.Device{}, parseErr
			}
			return model.Space{ID: spaceID, DisplayName: existingDisplayName, CreatedAt: createdAt}, device, nil
		}
		return model.Space{}, model.Device{}, storepkg.ErrSpaceExists
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return model.Space{}, model.Device{}, err
	}
	var deviceExists int
	err = tx.QueryRowContext(ctx, `SELECT 1 FROM devices WHERE id = ?`, deviceID).Scan(&deviceExists)
	if err == nil {
		return model.Space{}, model.Device{}, storepkg.ErrDeviceExists
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return model.Space{}, model.Device{}, err
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO family_spaces(id, display_name, created_at, next_seq) VALUES (?, ?, ?, 0)`,
		spaceID, displayName, formatTime(now)); err != nil {
		return model.Space{}, model.Device{}, err
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO devices(id, family_space_id, token_hash, role, display_name, created_at) VALUES (?, ?, ?, 'owner', ?, ?)`,
		deviceID, spaceID, tokenHash, deviceDisplayName, formatTime(now)); err != nil {
		return model.Space{}, model.Device{}, err
	}
	if err := tx.Commit(); err != nil {
		return model.Space{}, model.Device{}, err
	}
	return model.Space{ID: spaceID, DisplayName: displayName, CreatedAt: now}, model.Device{
		ID: deviceID, FamilySpaceID: spaceID, Role: "owner", DisplayName: deviceDisplayName, CreatedAt: now,
	}, nil
}

func (s *Store) AuthenticateDevice(ctx context.Context, deviceID string, tokenHash []byte) (model.Device, error) {
	var device model.Device
	var storedHash []byte
	var createdAt string
	var lastSeenAt sql.NullString
	err := s.db.QueryRowContext(ctx, `
		SELECT id, family_space_id, role, display_name, token_hash, created_at, last_seen_at
		FROM devices
		WHERE id = ? AND revoked_at IS NULL`, deviceID,
	).Scan(&device.ID, &device.FamilySpaceID, &device.Role, &device.DisplayName, &storedHash, &createdAt, &lastSeenAt)
	if errors.Is(err, sql.ErrNoRows) {
		return model.Device{}, storepkg.ErrUnauthorized
	}
	if err != nil {
		return model.Device{}, err
	}
	if subtle.ConstantTimeCompare(storedHash, tokenHash) != 1 {
		return model.Device{}, storepkg.ErrUnauthorized
	}
	device.CreatedAt, err = time.Parse(time.RFC3339Nano, createdAt)
	if err != nil {
		return model.Device{}, err
	}
	device.LastSeenAt, err = parseNullableTime(lastSeenAt)
	if err != nil {
		return model.Device{}, err
	}
	return device, nil
}

func (s *Store) CreateInvite(ctx context.Context, spaceID, creatorDeviceID, role string, tokenHash []byte, expiresAt time.Time) (model.Invite, error) {
	if role != "owner" && role != "member" {
		return model.Invite{}, storepkg.ErrForbidden
	}
	inviteID, err := id.NewUUID()
	if err != nil {
		return model.Invite{}, err
	}
	now := time.Now().UTC()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return model.Invite{}, err
	}
	defer tx.Rollback()
	if err := requireOwner(ctx, tx, spaceID, creatorDeviceID); err != nil {
		return model.Invite{}, err
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO invites(
			id, family_space_id, token_hash, created_by_device_id, role, created_at, expires_at
		) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		inviteID, spaceID, tokenHash, creatorDeviceID, role, formatTime(now), formatTime(expiresAt),
	); err != nil {
		return model.Invite{}, err
	}
	if err := tx.Commit(); err != nil {
		return model.Invite{}, err
	}
	return model.Invite{
		ID: inviteID, FamilySpaceID: spaceID, CreatedByDeviceID: creatorDeviceID,
		Role: role, CreatedAt: now, ExpiresAt: expiresAt.UTC(),
	}, nil
}

func (s *Store) ConsumeInvite(ctx context.Context, inviteID string, inviteTokenHash []byte, deviceID, displayName string, deviceTokenHash []byte) (model.Device, error) {
	now := time.Now().UTC()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return model.Device{}, err
	}
	defer tx.Rollback()
	var familySpaceID, role, expiresAtText string
	var storedHash []byte
	var consumedAt, consumedByDeviceID, revokedAt sql.NullString
	err = tx.QueryRowContext(ctx, `
		SELECT family_space_id, role, token_hash, expires_at, consumed_at, consumed_by_device_id, revoked_at
		FROM invites WHERE id = ?`, inviteID,
	).Scan(&familySpaceID, &role, &storedHash, &expiresAtText, &consumedAt, &consumedByDeviceID, &revokedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return model.Device{}, storepkg.ErrNotFound
	}
	if err != nil {
		return model.Device{}, err
	}
	if subtle.ConstantTimeCompare(storedHash, inviteTokenHash) != 1 {
		return model.Device{}, storepkg.ErrUnauthorized
	}
	if revokedAt.Valid {
		return model.Device{}, storepkg.ErrInviteRevoked
	}
	if consumedAt.Valid {
		if consumedByDeviceID.Valid && consumedByDeviceID.String == deviceID {
			device, storedDeviceTokenHash, err := deviceForInviteRetry(ctx, tx, familySpaceID, deviceID)
			if err != nil {
				return model.Device{}, err
			}
			if subtle.ConstantTimeCompare(storedDeviceTokenHash, deviceTokenHash) == 1 {
				return device, nil
			}
		}
		return model.Device{}, storepkg.ErrInviteConsumed
	}
	expiresAt, err := time.Parse(time.RFC3339Nano, expiresAtText)
	if err != nil {
		return model.Device{}, err
	}
	if !expiresAt.After(now) {
		return model.Device{}, storepkg.ErrInviteExpired
	}
	var exists int
	err = tx.QueryRowContext(ctx, `SELECT 1 FROM devices WHERE id = ?`, deviceID).Scan(&exists)
	if err == nil {
		return model.Device{}, storepkg.ErrDeviceExists
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return model.Device{}, err
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO devices(id, family_space_id, token_hash, role, display_name, created_at)
		VALUES (?, ?, ?, ?, ?, ?)`,
		deviceID, familySpaceID, deviceTokenHash, role, displayName, formatTime(now),
	); err != nil {
		return model.Device{}, err
	}
	result, err := tx.ExecContext(ctx, `
		UPDATE invites SET consumed_at = ?, consumed_by_device_id = ?
		WHERE id = ? AND consumed_at IS NULL AND revoked_at IS NULL`,
		formatTime(now), deviceID, inviteID)
	if err != nil {
		return model.Device{}, err
	}
	updated, err := result.RowsAffected()
	if err != nil {
		return model.Device{}, err
	}
	if updated != 1 {
		return model.Device{}, storepkg.ErrInviteConsumed
	}
	if err := tx.Commit(); err != nil {
		return model.Device{}, err
	}
	return model.Device{
		ID: deviceID, FamilySpaceID: familySpaceID, Role: role,
		DisplayName: displayName, CreatedAt: now,
	}, nil
}

func (s *Store) ListDevices(ctx context.Context, spaceID, requesterDeviceID string) ([]model.Device, error) {
	tx, err := s.db.BeginTx(ctx, &sql.TxOptions{ReadOnly: true})
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	if err := requireOwner(ctx, tx, spaceID, requesterDeviceID); err != nil {
		return nil, err
	}
	rows, err := tx.QueryContext(ctx, `
		SELECT id, family_space_id, role, display_name, created_at, last_seen_at, revoked_at
		FROM devices WHERE family_space_id = ? ORDER BY created_at, id`, spaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	devices := make([]model.Device, 0)
	for rows.Next() {
		var device model.Device
		var createdAt string
		var lastSeenAt, revokedAt sql.NullString
		if err := rows.Scan(&device.ID, &device.FamilySpaceID, &device.Role, &device.DisplayName, &createdAt, &lastSeenAt, &revokedAt); err != nil {
			return nil, err
		}
		device.CreatedAt, err = time.Parse(time.RFC3339Nano, createdAt)
		if err != nil {
			return nil, err
		}
		device.LastSeenAt, err = parseNullableTime(lastSeenAt)
		if err != nil {
			return nil, err
		}
		device.RevokedAt, err = parseNullableTime(revokedAt)
		if err != nil {
			return nil, err
		}
		devices = append(devices, device)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return devices, nil
}

func (s *Store) RevokeDevice(ctx context.Context, spaceID, requesterDeviceID, targetDeviceID string) (time.Time, error) {
	if requesterDeviceID == targetDeviceID {
		return time.Time{}, storepkg.ErrForbidden
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return time.Time{}, err
	}
	defer tx.Rollback()
	if err := requireOwner(ctx, tx, spaceID, requesterDeviceID); err != nil {
		return time.Time{}, err
	}
	var existingRevokedAt sql.NullString
	err = tx.QueryRowContext(ctx, `
		SELECT revoked_at FROM devices WHERE id = ? AND family_space_id = ?`,
		targetDeviceID, spaceID,
	).Scan(&existingRevokedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return time.Time{}, storepkg.ErrNotFound
	}
	if err != nil {
		return time.Time{}, err
	}
	if existingRevokedAt.Valid {
		revokedAt, err := time.Parse(time.RFC3339Nano, existingRevokedAt.String)
		if err != nil {
			return time.Time{}, err
		}
		return revokedAt, nil
	}
	revokedAt := time.Now().UTC()
	result, err := tx.ExecContext(ctx, `
		UPDATE devices SET revoked_at = ?
		WHERE id = ? AND family_space_id = ? AND revoked_at IS NULL`,
		formatTime(revokedAt), targetDeviceID, spaceID)
	if err != nil {
		return time.Time{}, err
	}
	updated, err := result.RowsAffected()
	if err != nil {
		return time.Time{}, err
	}
	if updated != 1 {
		return time.Time{}, errors.New("device revoke lost update")
	}
	if err := tx.Commit(); err != nil {
		return time.Time{}, err
	}
	return revokedAt, nil
}

func (s *Store) Exchange(ctx context.Context, spaceID, deviceID string, after int64, outgoing []model.OutgoingEnvelope, limit int) (model.ExchangeResult, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return model.ExchangeResult{}, err
	}
	defer tx.Rollback()

	var exists int
	if err := tx.QueryRowContext(ctx,
		`SELECT 1 FROM devices WHERE id = ? AND family_space_id = ? AND revoked_at IS NULL`, deviceID, spaceID,
	).Scan(&exists); errors.Is(err, sql.ErrNoRows) {
		return model.ExchangeResult{}, storepkg.ErrUnauthorized
	} else if err != nil {
		return model.ExchangeResult{}, err
	}

	acknowledged := make([]string, 0, len(outgoing))
	for _, envelope := range outgoing {
		if envelope.SourceDeviceID != deviceID {
			return model.ExchangeResult{}, storepkg.ErrUnauthorized
		}
		duplicate, err := existingEnvelope(ctx, tx, spaceID, envelope.ChangeID)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return model.ExchangeResult{}, err
		}
		if err == nil {
			if duplicate.EnvelopeVersion != envelope.EnvelopeVersion ||
				duplicate.SourceDeviceID != envelope.SourceDeviceID ||
				duplicate.Nonce != envelope.Nonce || duplicate.Ciphertext != envelope.Ciphertext {
				return model.ExchangeResult{}, storepkg.ErrChangeConflict
			}
			acknowledged = append(acknowledged, envelope.ChangeID)
			continue
		}

		var seq int64
		if err := tx.QueryRowContext(ctx,
			`UPDATE family_spaces SET next_seq = next_seq + 1 WHERE id = ? RETURNING next_seq`, spaceID,
		).Scan(&seq); errors.Is(err, sql.ErrNoRows) {
			return model.ExchangeResult{}, storepkg.ErrNotFound
		} else if err != nil {
			return model.ExchangeResult{}, err
		}
		receivedAt := time.Now().UTC()
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO changes(
				family_space_id, server_seq, change_id, source_device_id,
				envelope_version, nonce, ciphertext, received_at
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			spaceID, seq, envelope.ChangeID, envelope.SourceDeviceID,
			envelope.EnvelopeVersion, envelope.Nonce, envelope.Ciphertext, formatTime(receivedAt),
		); err != nil {
			return model.ExchangeResult{}, err
		}
		acknowledged = append(acknowledged, envelope.ChangeID)
	}

	rows, err := tx.QueryContext(ctx, `
		SELECT server_seq, received_at, envelope_version, change_id, source_device_id, nonce, ciphertext
		FROM changes
		WHERE family_space_id = ? AND server_seq > ?
		ORDER BY server_seq
		LIMIT ?`, spaceID, after, limit+1)
	if err != nil {
		return model.ExchangeResult{}, err
	}
	incoming := make([]model.IncomingEnvelope, 0, limit+1)
	for rows.Next() {
		var item model.IncomingEnvelope
		var receivedAt string
		if err := rows.Scan(&item.ServerSeq, &receivedAt, &item.EnvelopeVersion, &item.ChangeID, &item.SourceDeviceID, &item.Nonce, &item.Ciphertext); err != nil {
			rows.Close()
			return model.ExchangeResult{}, err
		}
		item.ReceivedAt, err = time.Parse(time.RFC3339Nano, receivedAt)
		if err != nil {
			rows.Close()
			return model.ExchangeResult{}, err
		}
		incoming = append(incoming, item)
	}
	if err := rows.Close(); err != nil {
		return model.ExchangeResult{}, err
	}
	if err := rows.Err(); err != nil {
		return model.ExchangeResult{}, err
	}

	hasMore := len(incoming) > limit
	if hasMore {
		incoming = incoming[:limit]
	}
	nextCursor := after
	if len(incoming) > 0 {
		nextCursor = incoming[len(incoming)-1].ServerSeq
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO device_cursors(family_space_id, device_id, last_reported_seq, updated_at)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(family_space_id, device_id) DO UPDATE SET
			last_reported_seq = MAX(last_reported_seq, excluded.last_reported_seq),
			updated_at = excluded.updated_at`,
		spaceID, deviceID, after, formatTime(time.Now())); err != nil {
		return model.ExchangeResult{}, err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE devices SET last_seen_at = ? WHERE id = ?`, formatTime(time.Now()), deviceID); err != nil {
		return model.ExchangeResult{}, err
	}
	if err := tx.Commit(); err != nil {
		return model.ExchangeResult{}, err
	}
	return model.ExchangeResult{
		AcknowledgedChangeIDs: acknowledged,
		Incoming:              incoming,
		NextCursor:            nextCursor,
		HasMore:               hasMore,
	}, nil
}

func existingEnvelope(ctx context.Context, tx *sql.Tx, spaceID, changeID string) (model.OutgoingEnvelope, error) {
	var envelope model.OutgoingEnvelope
	err := tx.QueryRowContext(ctx, `
		SELECT envelope_version, change_id, source_device_id, nonce, ciphertext
		FROM changes WHERE family_space_id = ? AND change_id = ?`, spaceID, changeID,
	).Scan(&envelope.EnvelopeVersion, &envelope.ChangeID, &envelope.SourceDeviceID, &envelope.Nonce, &envelope.Ciphertext)
	return envelope, err
}

func deviceForInviteRetry(ctx context.Context, tx *sql.Tx, spaceID, deviceID string) (model.Device, []byte, error) {
	var device model.Device
	var tokenHash []byte
	var createdAt string
	var lastSeenAt, revokedAt sql.NullString
	err := tx.QueryRowContext(ctx, `
		SELECT id, family_space_id, role, display_name, token_hash, created_at, last_seen_at, revoked_at
		FROM devices WHERE id = ? AND family_space_id = ?`, deviceID, spaceID,
	).Scan(
		&device.ID, &device.FamilySpaceID, &device.Role, &device.DisplayName,
		&tokenHash, &createdAt, &lastSeenAt, &revokedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return model.Device{}, nil, storepkg.ErrInviteConsumed
	}
	if err != nil {
		return model.Device{}, nil, err
	}
	if revokedAt.Valid {
		return model.Device{}, nil, storepkg.ErrInviteRevoked
	}
	device.CreatedAt, err = time.Parse(time.RFC3339Nano, createdAt)
	if err != nil {
		return model.Device{}, nil, err
	}
	device.LastSeenAt, err = parseNullableTime(lastSeenAt)
	if err != nil {
		return model.Device{}, nil, err
	}
	return device, tokenHash, nil
}

func requireOwner(ctx context.Context, tx *sql.Tx, spaceID, deviceID string) error {
	var role string
	err := tx.QueryRowContext(ctx, `
		SELECT role FROM devices
		WHERE id = ? AND family_space_id = ? AND revoked_at IS NULL`, deviceID, spaceID,
	).Scan(&role)
	if errors.Is(err, sql.ErrNoRows) {
		return storepkg.ErrUnauthorized
	}
	if err != nil {
		return err
	}
	if role != "owner" {
		return storepkg.ErrForbidden
	}
	return nil
}

func parseNullableTime(value sql.NullString) (*time.Time, error) {
	if !value.Valid {
		return nil, nil
	}
	parsed, err := time.Parse(time.RFC3339Nano, value.String)
	if err != nil {
		return nil, err
	}
	return &parsed, nil
}

func formatTime(value time.Time) string { return value.UTC().Format(time.RFC3339Nano) }
