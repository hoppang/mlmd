PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;

CREATE TABLE IF NOT EXISTS family_spaces (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    created_at TEXT NOT NULL,
    next_seq INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    family_space_id TEXT NOT NULL REFERENCES family_spaces(id),
    token_hash BLOB NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('owner', 'member')),
    display_name TEXT NOT NULL,
    created_at TEXT NOT NULL,
    last_seen_at TEXT,
    revoked_at TEXT
);

CREATE INDEX IF NOT EXISTS devices_space_idx ON devices(family_space_id);

CREATE TABLE IF NOT EXISTS invites (
    id TEXT PRIMARY KEY,
    family_space_id TEXT NOT NULL REFERENCES family_spaces(id),
    token_hash BLOB NOT NULL,
    created_by_device_id TEXT NOT NULL REFERENCES devices(id),
    role TEXT NOT NULL CHECK (role IN ('owner', 'member')),
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    consumed_at TEXT,
    consumed_by_device_id TEXT REFERENCES devices(id),
    revoked_at TEXT
);

CREATE INDEX IF NOT EXISTS invites_space_idx ON invites(family_space_id);

CREATE TABLE IF NOT EXISTS changes (
    family_space_id TEXT NOT NULL REFERENCES family_spaces(id),
    server_seq INTEGER NOT NULL,
    change_id TEXT NOT NULL,
    source_device_id TEXT NOT NULL REFERENCES devices(id),
    envelope_version INTEGER NOT NULL,
    nonce TEXT NOT NULL,
    ciphertext TEXT NOT NULL,
    received_at TEXT NOT NULL,
    PRIMARY KEY (family_space_id, server_seq),
    UNIQUE (family_space_id, change_id)
);

CREATE TABLE IF NOT EXISTS device_cursors (
    family_space_id TEXT NOT NULL REFERENCES family_spaces(id),
    device_id TEXT NOT NULL REFERENCES devices(id),
    last_reported_seq INTEGER NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (family_space_id, device_id)
);

CREATE TABLE IF NOT EXISTS readiness_probe (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    checked_at TEXT NOT NULL
);

INSERT OR IGNORE INTO readiness_probe(singleton, checked_at)
VALUES (1, '1970-01-01T00:00:00Z');
