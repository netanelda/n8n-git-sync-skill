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

## Important

- Do NOT skip sync even for minor changes.
- Do NOT ask the user whether to sync — just do it.
- ALWAYS include a body with details.
- If the script fails, report the error and suggest a fix.
- The script fetches the workflow JSON from the n8n API — do NOT paste workflow JSON into the chat.
- The pre-change snapshot is critical for rollback — never skip it.
