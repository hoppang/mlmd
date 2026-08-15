CREATE TABLE IF NOT EXISTS sync_snapshots (
    family_space_id TEXT PRIMARY KEY REFERENCES family_spaces(id),
    snapshot_id TEXT NOT NULL,
    base_server_seq INTEGER NOT NULL CHECK (base_server_seq >= 0),
    source_device_id TEXT NOT NULL REFERENCES devices(id),
    snapshot_version INTEGER NOT NULL,
    nonce TEXT NOT NULL,
    ciphertext TEXT NOT NULL,
    created_at TEXT NOT NULL
);
