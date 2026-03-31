---
name: n8n-git-sync-setup
description: Set up automated Git version control for n8n workflows in any Cursor project. Creates sync script, Cursor rule, and Git configuration. Use when the user says "set up n8n sync", "add workflow version control", "initialize n8n git sync", "set up workflow backup", or wants to version-control n8n workflows with Git.
---

# n8n Git Sync Setup

Scaffolds an automated Git sync system for n8n workflows in the current project. After setup, every workflow change made via MCP is automatically fetched from the n8n API and committed to Git — no manual steps, no token waste.

Workflows enter Git tracking automatically the first time they are modified via MCP. There is no bulk sync — only workflows actively worked on in this project are tracked.

## Prerequisites

- `curl` and `jq` installed (standard on macOS/Linux)
- Git installed
- n8n instance with API access enabled
- GitHub repo (existing or new)

## Setup Workflow

### Step 1: Check Global Credentials

Check if `~/.n8n-sync/.env` exists:

```bash
cat ~/.n8n-sync/.env
```

**If it exists:** Confirm with the user that the credentials are correct, then proceed to Step 2.

**If it does NOT exist:** Ask the user for:
1. `N8N_BASE_URL` — their n8n instance URL (e.g., `https://n8n.example.com`)
2. `N8N_API_KEY` — API key from n8n Settings > API

Then create the global credentials file:

```bash
mkdir -p ~/.n8n-sync
```

Write to `~/.n8n-sync/.env`:
```
# Global n8n API credentials
N8N_BASE_URL=<user-provided-url>
N8N_API_KEY=<user-provided-key>
```

### Step 2: Initialize Git (if needed)

Check if the project already has a git repo:

```bash
git status
```

If not initialized:
1. Run `git init`
2. Ask the user for the GitHub repo URL, or detect it from context
3. Run `git remote add origin <repo-url>`

### Step 3: Create Project Files

Create the following files in the project root. Read each file from the reference templates below and write them to the project.

**Files to create:**
1. `sync_n8n.sh` — workflow sync script (make executable with `chmod +x`)
2. `.cursor/rules/n8n-git-sync.mdc` — auto-sync project rule
3. `.gitignore` — add `.env` and `.DS_Store` if not already present

Do NOT create a project-level `.env` — the global one at `~/.n8n-sync/.env` is used by default.

### Step 4: Initial Commit

```bash
git add -A
git commit -m "Set up n8n workflow Git auto-sync" -m "Added sync_n8n.sh and Cursor auto-sync rule"
git push -u origin main
```

### Step 5: Sync Existing Workflows (if any)

Ask the user: "Which n8n workflows are you working on in this project? Paste the URLs or IDs."

For each workflow ID, run:

```bash
./sync_n8n.sh <WORKFLOW_ID> "Initial sync: <workflow-name>" "First backup of this workflow"
```

From this point on, the Cursor rule handles everything automatically.

## Reference: sync_n8n.sh

The workflow sync script. Accepts `<WORKFLOW_ID> "<TITLE>" ["<BODY>"]`.

Key features:
- **Credential sanitization**: Strips all secrets from JSON before committing. Credential reference IDs are preserved (safe), but actual API keys, tokens, and session data are redacted. Secrets remain in n8n's encrypted store only.
- Loads credentials from project `.env` first, then falls back to `~/.n8n-sync/.env`
- Extracts workflow name from JSON, sanitizes it, uses it as the filename
- Maintains `n8n-workflows/.id-map.json` to track ID-to-filename mapping
- Handles workflow renames via `git mv`
- Auto-generates `n8n-workflows/README.md` index after each sync
- Pretty-prints JSON for readable Git diffs

Read the reference implementation: [sync_n8n.sh](sync_n8n.sh)

## Reference: n8n-git-sync.mdc

The Cursor project rule that triggers auto-sync. It instructs the AI to:
1. Run a pre-change snapshot before modifying any workflow
2. Run a post-change sync after every successful MCP modification
3. Write detailed commit messages (title + body) without asking the user
4. Revert workflows to a previous Git version when asked — using credential IDs preserved in Git to reconnect secrets automatically in n8n

Read the reference implementation: [n8n-git-sync.mdc](n8n-git-sync.mdc)

## Verification

After setup, verify the system works:

```bash
source ~/.n8n-sync/.env && echo "Base URL: $N8N_BASE_URL"
curl -s -o /dev/null -w "%{http_code}" -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE_URL/api/v1/workflows?limit=1"
```

Expected: HTTP 200.
