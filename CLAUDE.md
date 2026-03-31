# n8n Workflow Git Auto-Sync

This project uses automated Git version control for n8n workflows.

## When This Applies

Whenever you interact with n8n workflows via MCP tools:
- `n8n_create_workflow`
- `n8n_update_partial_workflow`
- `n8n_update_full_workflow`

## Required Behavior

### Before Modifying a Workflow

Run a pre-change snapshot to capture the current state:

```bash
./sync_n8n.sh <WORKFLOW_ID> "Snapshot before modifying <workflow-name>" "Pre-change backup before: <what you are about to do>"
```

If the script reports "No changes detected", that is fine.

### After Successfully Modifying a Workflow

Immediately run — without asking for user permission:

```bash
./sync_n8n.sh <WORKFLOW_ID> "<TITLE>" "<BODY>"
```

**TITLE**: Concise one-liner in imperative mood (under 72 chars).
Examples: "Add webhook trigger for form submissions", "Connect IF node to error handler"

**BODY**: Detailed changelog as bullet points:
- Which nodes were added, removed, or modified (by name and type)
- Which connections were created or changed
- What parameters were updated and to what values
- The reason / intent behind the change

## Reverting a Workflow to a Previous Version

When the user asks to revert / roll back a workflow:

1. **Find the target version:**
```bash
git log --oneline n8n-workflows/<filename>.json
```

2. **Extract the old version from Git:**
```bash
git show <COMMIT_HASH>:n8n-workflows/<filename>.json > /tmp/revert-payload.json
```

3. **Push the reverted version to n8n** — credential IDs in Git are safe references; n8n reconnects them automatically:
```bash
source ~/.n8n-sync/.env 2>/dev/null || source .env
REVERT_PAYLOAD=$(jq '{name: .name, nodes: .nodes, connections: .connections, settings: {executionOrder: (.settings.executionOrder // "v1")}}' /tmp/revert-payload.json)
curl -s -X PUT -H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json" -d "$REVERT_PAYLOAD" "$N8N_BASE_URL/api/v1/workflows/<WORKFLOW_ID>"
```

4. **Sync the reverted state:**
```bash
./sync_n8n.sh <WORKFLOW_ID> "Revert <workflow-name> to <commit>" "Rolled back to commit <hash>"
```

### How credentials survive the revert

The sync script strips secret values but preserves credential reference IDs. When you push JSON back to n8n, it sees these IDs and reconnects to existing credentials in its encrypted store. No secrets need to be in Git.

## Credential Sanitization

`sync_n8n.sh` automatically strips secrets before committing:
- Credential values replaced with safe ID/name references
- JWT tokens, AWS keys, API key patterns redacted
- `staticData` removed (can contain session tokens)
- Workflow structure, nodes, and connections fully preserved

## Important

- Do NOT skip sync even for minor changes.
- Do NOT ask the user whether to sync — just do it.
- ALWAYS include a body with details.
- If the script fails, report the error and suggest a fix.
- The script fetches the workflow JSON from the n8n API — do NOT paste workflow JSON into the chat.
- The pre-change snapshot is critical for rollback — never skip it.
