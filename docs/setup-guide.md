# Setup guide: rebuilding this from zero

Placeholders: `<SERVER_IP>`, `<your-domain>`, `<you@example.com>`. Times are approximate.

## 1. Oracle Cloud server (30 min)

1. Create an Oracle Cloud account (Free Tier). Pick the home region carefully; it can't be changed later.
2. Create an SSH key on your PC:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/oracle_n8n -C "oracle-n8n"
   ```
3. Compute → Instances → **Create instance**:
   - Image: **Canonical Ubuntu 24.04** (not Minimal)
   - Shape: **VM.Standard.A1.Flex**, 4 OCPU / 24 GB (**Always Free-eligible**)
   - Networking: new VCN + new public subnet
   - SSH key: upload `oracle_n8n.pub`
   - Boot volume: 100 GB, VPU 10
4. If the form won't let you enable "Assign public IPv4" while creating a new subnet, create the instance anyway, then add the IP: Instance → Networking → VNIC → IP administration → Edit → **Ephemeral public IP**.
5. Connect and prepare the OS:
   ```bash
   ssh -i ~/.ssh/oracle_n8n ubuntu@<SERVER_IP>
   sudo apt update && sudo NEEDRESTART_MODE=a apt -y upgrade
   sudo timedatectl set-timezone Asia/Riyadh
   sudo reboot
   ```

## 2. Docker (5 min)

```bash
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu   # log out and back in
docker run --rm hello-world
```

## 3. Domain + Cloudflare Tunnel (15 min)

1. Buy the domain on Cloudflare Registrar (auto-renew on, 2FA on the account).
2. Zero Trust (Free plan) → Networks → Tunnels → **Create a tunnel** → Cloudflared → name it → choose Docker → copy only the token.
3. Don't run the suggested `docker run`; the token goes into `.env` (next step).

## 4. n8n + cloudflared (10 min)

```bash
mkdir -p ~/n8n && cd ~/n8n
echo "N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)" > .env && chmod 600 .env
read -rsp "Tunnel token: " T && echo && printf 'TUNNEL_TOKEN=%s\n' "$T" >> .env && unset T
# copy infra/docker-compose.yml from this repo to ~/n8n/docker-compose.yml, set your domain
docker compose config --quiet && docker compose up -d && docker compose ps
docker compose logs cloudflared | grep -i "registered tunnel connection"
```

Save `N8N_ENCRYPTION_KEY` in a password manager. Without it, restored credentials can't be decrypted.

## 5. Lock it down before publishing the hostname

Do this **before** adding the public hostname, or n8n's "create owner account" page is briefly open to the internet.

1. Zero Trust → Access → Applications → **Add application** → Self-hosted → hostname `n8n.<your-domain>`.
2. Policy: **Allow**, Include → **Emails** → `<you@example.com>`, session 24 h.
3. Integrations → Identity providers → add **One-time PIN** (so you can log in from any browser).

## 6. Publish the hostname

Tunnel → Routes → **Add published application**: `n8n.<your-domain>` → service `http://n8n:5678`.
Open `https://n8n.<your-domain>` → Access login → create the n8n owner account.

## 7. Move the workflows

1. Export each workflow from the old instance (⋯ → Download).
2. New instance: ⋯ → **Import from File** → Save. Imported workflows start inactive.
3. Install community nodes the workflows use (Settings → Community nodes, e.g. `@apify/n8n-nodes-apify`).
4. Re-create credentials (API keys + Google OAuth2) and select them in every node.
5. Google OAuth: in Google Cloud create an OAuth client (Web application) with redirect URI `https://n8n.<your-domain>/rest/oauth2-credential/callback`; keep the consent screen **In production**.
6. Test one node (Execute step), then a full run, then **Publish** the scheduled workflow.
7. Turn off the old instance's schedules so two instances never write to the same sheet.

## 8. Backups

Copy `infra/backup.sh` to `~/n8n/backup.sh`, `chmod +x`, test it once, then add `infra/crontab.txt` with `crontab -e`. Pull copies off the server monthly (see [operations.md](operations.md)).
