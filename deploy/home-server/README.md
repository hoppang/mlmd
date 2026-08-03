# MLMD home-server deployment

The Compose deployment runs the HTTP server and an independent encrypted
backup scheduler. The scheduler does not expose a port or receive the
bootstrap token, and the HTTP server does not receive the backup key.

## Prepare secrets and storage

Generate the bootstrap token and backup key outside the repository. Keep the
only backup-key copy off the database volume.

```sh
mkdir -p /srv/mlmd/backups /srv/mlmd/secrets
chmod 700 /srv/mlmd/backups /srv/mlmd/secrets
docker build -t mlmd-sync-server:local server
docker run --rm --user 0 -v /srv/mlmd/secrets:/keys mlmd-sync-server:local \
  generate-backup-key --output /keys/backup.key
```

The container runs as UID/GID `65532`. On Linux, grant that account write
access to the bind-mounted backup directory:

```sh
sudo chown 65532:65532 /srv/mlmd/backups
```

Set the Compose inputs in the shell or an uncommitted `.env` file:

```dotenv
MLMD_BOOTSTRAP_TOKEN=<at-least-32-random-characters>
MLMD_LAN_ADDRESS=192.168.1.20
MLMD_BACKUP_DIRECTORY=/srv/mlmd/backups
MLMD_BACKUP_KEY_FILE=/srv/mlmd/secrets/backup.key
MLMD_BACKUP_CHECK_INTERVAL=1h
```

Build and start both services:

```sh
docker compose -f deploy/home-server/compose.yaml up -d --build
```

The scheduler checks immediately at startup and then at the configured
interval. It creates at most one backup per UTC date. It retains every backup
from the latest seven UTC dates and the newest backup in each of the current
and previous seven ISO weeks. Only files named
`mlmd-auto-YYYY-MM-DD.mlmd-backup` are pruned; manual files are left alone.

Inspect recent scheduler activity with:

```sh
docker compose -f deploy/home-server/compose.yaml logs mlmd-backup
```

## Restore

Stop both services before restoring so neither the server nor scheduler holds
a database lock:

```sh
docker compose -f deploy/home-server/compose.yaml stop mlmd-backup mlmd-sync-server
docker compose -f deploy/home-server/compose.yaml run --rm --no-deps \
  mlmd-backup restore --input /backups/mlmd-auto-2026-08-03.mlmd-backup \
  --key-file /run/secrets/mlmd_backup_key
docker compose -f deploy/home-server/compose.yaml start mlmd-sync-server mlmd-backup
```

The restore command logs the directory containing the preserved pre-restore
database. Keep it until the server starts and all clients have synchronized.
