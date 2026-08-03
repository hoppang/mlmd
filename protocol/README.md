# Sync Protocol v1

This directory contains the language-neutral contract for the home server sync exchange described in `docs/HOME_SERVER_SYNC_PLAN.md`.

Files:

- `bootstrap-space-v1-*.schema.json`: first owner device and family-space bootstrap
- `invite-create-v1-*.schema.json`: owner-created, ten-minute pairing invite
- `invite-consume-v1-*.schema.json`: one-time invite consumption by a new device
- `devices-list-v1-response.schema.json`: owner device inventory
- `device-revoke-v1-response.schema.json`: owner device revocation result
- `pairing-qr-v1.schema.json`: decoded contents of the direct-scan pairing QR
- `exchange-v1-request.schema.json`: JSON Schema for sync requests
- `exchange-v1-response.schema.json`: JSON Schema for sync responses
- `envelope-v1.schema.json`: JSON Schema for the opaque encrypted envelope
- `invite-create-v1-request.schema.json`: JSON Schema for invite creation requests
- `invite-create-v1-response.schema.json`: JSON Schema for invite creation responses
- `invite-consume-v1-request.schema.json`: JSON Schema for invite consumption requests
- `invite-consume-v1-response.schema.json`: JSON Schema for invite consumption responses
- `devices-list-v1-response.schema.json`: JSON Schema for device list responses
- `device-revoke-v1-response.schema.json`: JSON Schema for device revoke responses
- `fixtures/`: golden request/response examples

Contract notes:

- `protocolVersion` is fixed to `1`
- `afterCursor` is `null` for initial sync and otherwise a non-empty decimal cursor string; `nextCursor` is always a decimal cursor string
- `limit` is capped at `200`
- `outgoing` is capped at `100` envelopes per request
- `acknowledgedChangeIds` is capped at `100` IDs per response
- `incoming` is capped at `200` envelopes per response
- Each nonce is exactly 24 bytes encoded as 32-character unpadded base64url
- Each decoded ciphertext, including its authentication tag, is bounded to `256 KiB`
- Request bodies are intended to stay under `2 MiB`
- Device and invite secrets are 32 random bytes encoded as 43-character unpadded base64url; the server stores only SHA-256 hashes
- A bootstrap retry must reuse the same client-generated family space ID, device ID, and device secret; the server returns the original result for that exact identity
- An invite-consume retry must reuse the same device ID and device secret; the server returns the original result only for that exact identity
- Revoking a device is idempotent: an exact retry returns the original `revokedAt`; the authenticated current device can never revoke itself
- The pairing QR is `mlmd://pair/v1?payload=<unpadded-base64url-json>` and contains the family key, so it must be scanned directly rather than shared as a screenshot
- XChaCha20-Poly1305 AAD is UTF-8 for `mlmd-sync-envelope`, envelope version, family space ID, change ID, and source device ID joined by NUL (`0x00`) bytes
- A conflict resolution's sorted `parentChangeIds`, local `sourceConflictId`, and selected result are fields of the encrypted `SyncChange` JSON, never plaintext envelope metadata
- Clients reconcile concurrent resolutions deterministically by the server-assigned sequence, with the change ID as the final fallback; the server does not inspect or resolve them
- Per-author resolution-notice acknowledgements are ordinary encrypted changes keyed by notice ID, winning change ID, and author profile ID; the server sees only another opaque envelope
