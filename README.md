# n8n Git Sync Skill for Cursor

Automated Git version control for n8n workflows. Every time Cursor AI modifies a workflow via MCP, the change is fetched from the n8n API and committed to GitHub — with human-readable filenames, detailed commit messages, and pre-change snapshots.

## What It Does

- **Auto-sync**: After every workflow change via MCP, the AI runs a script that fetches the workflow JSON and pushes it to Git
- **Pre-change snapshots**: Before modifying a workflow, the current state is committed — enabling easy rollback
- **Readable filenames**: Files are named by workflow name (e.g., `email-localization-bridge.json`), not by ID
- **Detailed commit history**: Every commit includes a title + body explaining what changed and why
- **Bulk sync**: One command to backup all workflows at once
- **Auto-generated index**: `n8n-workflows/README.md` with a table of all synced workflows

## Install

Clone this repo into your Cursor skills directory:

```bash
git clone https://github.com/netanelda/n8n-git-sync-skill ~/.cursor/skills/n8n-git-sync-setup
```

## Usage

In any Cursor project, say:

> "Set up n8n sync"

The skill will:
1. Check for global n8n credentials (or ask you to create them)
2. Create `sync_n8n.sh` and `sync_all_n8n.sh` in your project
3. Create a Cursor rule that triggers auto-sync after every MCP workflow change
4. Initialize Git and push to your repo

From that point on, every workflow change is automatically version-controlled.

## Global Credentials

Credentials are stored once at `~/.n8n-sync/.env` and shared across all projects:

```
N8N_BASE_URL=https://your-n8n-instance.example.com
N8N_API_KEY=your-api-key-here
```

Get your API key from: n8n Settings > API > Create API Key.

A project-level `.env` can override the global one if needed.

## What's Included

| File | Purpose |
|------|---------|
| `SKILL.md` | Cursor skill instructions — guides the AI through setup |
| `sync_n8n.sh` | Single-workflow sync script (template copied to each project) |
| `sync_all_n8n.sh` | Bulk sync script for all workflows |
| `n8n-git-sync.mdc` | Cursor project rule for auto-sync behavior |

## Requirements

- macOS or Linux
- `curl` and `jq` (pre-installed on macOS)
- Git
- Cursor IDE with n8n MCP configured
- n8n instance with API access enabled
