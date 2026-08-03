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

## Verify

```powershell
go test ./...
go vet ./...
```

The v1 wire contract and golden JSON live in the repository-level `protocol/` directory.
