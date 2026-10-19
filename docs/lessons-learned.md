# Lessons learned

Real problems from the migration and how each was diagnosed.

### 1. Google OAuth `invalid_client`
**Symptom:** the Google consent screen worked, but connecting failed with `invalid_client`.
**Cause:** the client secret saved in n8n wasn't the one Google expected (an extra-characters paste, then a secret that had just been created).
**How I proved it:** I tested the client ID + secret directly against Google's token endpoint from the server, outside n8n:
```bash
curl -s https://oauth2.googleapis.com/token -d client_id=... --data-urlencode client_secret=... \
  -d grant_type=authorization_code -d code=test -d redirect_uri=https://n8n.<domain>/rest/oauth2-credential/callback
```
`invalid_grant` = ID and secret are valid (only the fake code was rejected); `invalid_client` = the secret is wrong or not active yet.
**Fix:** a separate OAuth client just for the cloud instance, secret copied with the copy button, credential saved before signing in.

### 2. Lock first, then publish
Adding the public hostname exposes n8n's first-run "create owner" page. I created the Cloudflare Access application first, then published the route.

### 3. Oracle form wouldn't assign a public IP
When creating a new subnet inside the instance wizard, the public-IP toggle was disabled. Fix: create the instance, then attach an ephemeral public IP on the VNIC.

### 4. Community nodes don't move with the workflow
The Apify nodes are a community package. On the new instance they showed as unknown until `@apify/n8n-nodes-apify` was installed (it is stored on the persistent volume, so it survives updates).

### 5. CLI exports aren't UI imports
`n8n export:workflow` writes `[ {workflow} ]`; the editor's "Import from File" expects `{workflow}`. Unwrapping the array fixed "nodes and connections are missing".

### 6. Two instances, one sheet
Both the old (local) and new (cloud) instances write to the same Google Sheet, so only one may have schedules active. The dedupe step against the sheet made a same-day re-run write zero duplicates.

### 7. Secrets hygiene
- Tokens pasted into a terminal prompt with `read -s` never hit shell history or the screen.
- `clear` before screenshotting a terminal.
- Watch the browser's "save password?" prompt: it tried to save an API token as the site password.
- A token that leaks anywhere (chat, screenshot) gets rotated, not just deleted.

### 8. Browser profile issues are not outages
The Cloudflare dashboard failed in one Chrome profile but worked in a guest window, a clean profile and Brave. Isolating with a guest window answered "is it me or them?" in one step.
