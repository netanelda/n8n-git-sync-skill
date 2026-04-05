# n8n Git Sync Skill

Automated Git version control for n8n workflows. Works with both **Cursor** and **Claude Code**. Every time the AI modifies a workflow via MCP, the change is fetched from the n8n API and committed to GitHub — with human-readable filenames, detailed commit messages, and pre-change snapshots.

**Credentials are automatically stripped** from workflow JSON before committing. API keys, tokens, and secrets never reach Git. Credential reference IDs are preserved, so reverting a workflow automatically reconnects to existing credentials in n8n.

Only workflows you actively work on via MCP are tracked.

## Install

### For Cursor

```bash
git clone https://github.com/netanelda/n8n-git-sync-skill ~/.cursor/skills/n8n-git-sync-setup
```

### For Claude Code

```bash
git clone https://github.com/netanelda/n8n-git-sync-skill ~/.claude/skills/n8n-git-sync-setup
```

Then in any project, say: **"Set up n8n sync"**

## What Happens During Setup

1. Checks for global n8n credentials at `~/.n8n-sync/.env` (or asks you to create them)
2. Creates `sync_n8n.sh` and `sanitize_n8n_workflow.jq` in your project (credential + resource-ID sanitization)
3. Creates the appropriate rule file:
   - Cursor: `.cursor/rules/n8n-git-sync.mdc`
   - Claude Code: `CLAUDE.md`
4. Initializes Git and pushes to your repo
5. Asks which workflows you're working on and syncs them

## Key Features

- **Credential sanitization** — API keys, JWT tokens, AWS keys, and secrets are stripped from JSON before committing. Only safe credential reference IDs are kept. **File and folder IDs** (Google Sheets/Drive, Slack channels, Monday boards, etc.) are preserved — not treated as secrets.
- **Automatic revert** — Roll back any workflow to a previous Git version. Credential IDs in Git let n8n reconnect secrets automatically.
- **Pre-change snapshots** — Current state is committed before every modification, so you always have a clean "before" to diff against or revert to.
- **Human-readable filenames** — Files are named after the workflow (e.g., `email-localization-pipeline.json`), not by ID.
- **Auto-generated index** — `n8n-workflows/README.md` is updated after every sync with a table of all tracked workflows.

## Global Credentials

Set once, used across all projects:

```bash
mkdir -p ~/.n8n-sync
cat > ~/.n8n-sync/.env << 'EOF'
N8N_BASE_URL=https://your-n8n-instance.example.com
N8N_API_KEY=your-api-key-here
EOF
```

Get your API key from: n8n Settings > API > Create API Key.

## What's Included

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill instructions (works in both Cursor and Claude Code) |
| `sync_n8n.sh` | Workflow sync script (template copied to each project) |
| `sanitize_n8n_workflow.jq` | Sanitization rules (must sit next to `sync_n8n.sh`) |
| `n8n-git-sync.mdc` | Cursor project rule for auto-sync |
| `CLAUDE.md` | Claude Code project rule for auto-sync |

## Requirements

- macOS or Linux
- `curl` and `jq` (pre-installed on macOS)
- Git
- Cursor or Claude Code with n8n MCP configured
- n8n instance with API access enabled
