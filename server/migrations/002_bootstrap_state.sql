CREATE TABLE IF NOT EXISTS bootstrap_state (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    family_space_id TEXT NOT NULL REFERENCES family_spaces(id),
    device_id TEXT NOT NULL REFERENCES devices(id),
    consumed_at TEXT NOT NULL
);

-- Existing installations that already have a family space must not reopen
-- bootstrap after upgrading. The oldest owner is the retry identity.
INSERT OR IGNORE INTO bootstrap_state(
    singleton, family_space_id, device_id, consumed_at
)
SELECT 1, spaces.id, devices.id, spaces.created_at
FROM family_spaces AS spaces
JOIN devices ON devices.family_space_id = spaces.id
WHERE devices.role = 'owner'
ORDER BY spaces.created_at, devices.created_at
LIMIT 1;
