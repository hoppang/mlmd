CREATE TABLE IF NOT EXISTS compacted_changes (
    family_space_id TEXT NOT NULL,
    change_id TEXT NOT NULL,
    envelope_fingerprint BLOB NOT NULL CHECK(length(envelope_fingerprint) = 32),
    PRIMARY KEY (family_space_id, change_id),
    FOREIGN KEY (family_space_id) REFERENCES family_spaces(id) ON DELETE CASCADE
);
