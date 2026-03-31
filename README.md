# n8n Git Sync Skill

Automated Git version control for n8n workflows. Works with both **Cursor** and **Claude Code**. Every time the AI modifies a workflow via MCP, the change is fetched from the n8n API and committed to GitHub — with human-readable filenames, detailed commit messages, and pre-change snapshots.

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
2. Creates `sync_n8n.sh` in your project
3. Creates the appropriate rule file:
   - Cursor: `.cursor/rules/n8n-git-sync.mdc`
   - Claude Code: `CLAUDE.md`
4. Initializes Git and pushes to your repo
5. Asks which workflows you're working on and syncs them

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
| `n8n-git-sync.mdc` | Cursor project rule for auto-sync |
| `CLAUDE.md` | Claude Code project rule for auto-sync |

## Requirements

- macOS or Linux
- `curl` and `jq` (pre-installed on macOS)
- Git
- Cursor or Claude Code with n8n MCP configured
- n8n instance with API access enabled
