#!/bin/bash
# Daily n8n backup: workflows + credentials (credentials stay encrypted with N8N_ENCRYPTION_KEY).
# Lives on the server at /home/ubuntu/n8n/backup.sh, run by cron. Keeps 14 days.
set -euo pipefail
cd /home/ubuntu/n8n
TS=$(date +%F)
DIR=/home/ubuntu/n8n/backups
mkdir -p "$DIR/$TS"
docker compose exec -T n8n sh -c 'rm -rf /tmp/bk && mkdir -p /tmp/bk && n8n export:workflow --all --pretty --output=/tmp/bk/workflows.json && n8n export:credentials --all --output=/tmp/bk/credentials.json'
docker compose cp n8n:/tmp/bk/. "$DIR/$TS/"
docker compose exec -T n8n rm -rf /tmp/bk
tar -czf "$DIR/n8n-$TS.tgz" -C "$DIR" "$TS" && rm -rf "${DIR:?}/$TS"
find "$DIR" -name 'n8n-*.tgz' -mtime +14 -delete
echo "$(date '+%F %T') backup ok: n8n-$TS.tgz"
