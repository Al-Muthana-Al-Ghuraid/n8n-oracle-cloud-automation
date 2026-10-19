# Operations

## Daily (automatic)

| Time (Asia/Riyadh) | What |
|---|---|
| 03:30 | `backup.sh`: exports all workflows + credentials (encrypted), keeps 14 days |
| 09:00 | Job Applications workflow runs |

Check a run: workflow → **Executions** tab.

## Monthly

**Copy backups off the server** (from the PC):
```bash
scp -i ~/.ssh/oracle_n8n "ubuntu@<SERVER_IP>:~/n8n/backups/*.tgz" ./n8n-backups/
```

**Update n8n and cloudflared:**
```bash
cd ~/n8n && docker compose pull && docker compose up -d && docker image prune -f
```

**Update Ubuntu:**
```bash
sudo apt update && sudo NEEDRESTART_MODE=a apt -y upgrade   # reboot if a new kernel was installed
```

**Check spend:** Apify usage, OpenAI usage/budget.

## Restore

You need a backup `.tgz` **and** the original `N8N_ENCRYPTION_KEY`.

```bash
cd ~/n8n
tar -xzf n8n-YYYY-MM-DD.tgz
docker compose cp YYYY-MM-DD/. n8n:/tmp/restore/
docker compose exec n8n n8n import:workflow --input=/tmp/restore/workflows.json
docker compose exec n8n n8n import:credentials --input=/tmp/restore/credentials.json
```

## Health checks

```bash
docker compose ps                                   # both containers "Up"
docker compose logs --tail 50 n8n
docker compose logs cloudflared | grep -i registered   # tunnel connections
tail -n 5 ~/n8n/backups/backup.log                  # last nightly backup
free -h && df -h /
```

## Oracle "idle instance" policy

Oracle can reclaim Always Free instances that stay almost idle (very low CPU, network and memory) for 7 days. If Oracle sends an idle-instance notice, options are: upgrade the account to Pay As You Go (still $0 on Always Free shapes, add a budget alert), or restore onto a new instance from the backups.
