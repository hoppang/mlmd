# MLMD home sync server

This Go module is the home-server side of MLMD's encrypted change-log sync. The server authenticates devices, assigns a per-space sequence, deduplicates change IDs, and stores opaque E2EE envelopes. It does not decrypt diary data or resolve content conflicts.

## Run locally

```powershell
$env:MLMD_BOOTSTRAP_TOKEN = '<at-least-32-random-characters>'
go run ./cmd/mlmd-server
```

Defaults:

- listen address: `127.0.0.1:8080`
- database: `data/mlmd.db`

Set `MLMD_LISTEN_ADDR` and `MLMD_DATABASE_PATH` to override them. Keep the default loopback binding during development. Bind to a LAN address only together with the firewall restrictions described in `docs/HOME_SERVER_SYNC_PLAN.md`.

Create the first family space with the bootstrap token:

```http
POST /v1/bootstrap/spaces
Authorization: Bearer <bootstrap token>
Content-Type: application/json

{
  "displayName": "우리 가족",
  "deviceId": "<앱의 현재 deviceProfileId UUID>",
  "deviceDisplayName": "관리자 휴대폰",
  "deviceSecret": "<32 random bytes as unpadded base64url>"
}
```

The app keeps the generated secret and authenticates subsequent requests with `Bearer <deviceId>.<deviceSecret>`. The server stores only its SHA-256 hash.

Implemented management endpoints:

- `POST /v1/spaces/{spaceId}/invites`
- `POST /v1/invites/{inviteId}/consume`
- `GET /v1/spaces/{spaceId}/devices`
- `DELETE /v1/spaces/{spaceId}/devices/{deviceId}`

## Create an encrypted SQLite backup

Generate a 256-bit backup key once and keep it outside the server data volume:

```powershell
$keyPath = '..\mlmd-secrets\backup.key'
go run ./cmd/mlmd-server generate-backup-key --output $keyPath
```

The backup command can run while the HTTP server is using the WAL database:

```powershell
$env:MLMD_DATABASE_PATH = 'data/mlmd.db'
go run ./cmd/mlmd-server backup --key-file $keyPath --output 'backups/mlmd-2026-08-03.mlmd-backup'
```

For automation or a container exec, `MLMD_BACKUP_KEY` may contain the same
unpadded base64url key instead of using `--key-file`:

```sh
export MLMD_BACKUP_KEY="$(cat /secure/mlmd-backup.key)"
docker compose -f deploy/home-server/compose.yaml exec \
  -e MLMD_BACKUP_KEY mlmd-sync-server \
  /mlmd-server backup --output /data/backups/mlmd-2026-08-03.mlmd-backup
```

The command uses SQLite's transactional `VACUUM INTO` snapshot, validates it
with `PRAGMA quick_check`, then encrypts it with chunked AES-256-GCM before
publishing it. The authenticated final record detects truncation, and an
existing destination is never overwritten. The temporary plaintext snapshot
stays beside the protected source database and is removed after encryption.

Losing the backup key makes every backup encrypted with it unrecoverable. Do
not store the only key copy in the same volume as `mlmd.db`. The restore CLI
is the next implementation step; the encrypted format already has verified
decryption tests.

## Verify

```powershell
go test ./...
go vet ./...
```

The v1 wire contract and golden JSON live in the repository-level `protocol/` directory.
