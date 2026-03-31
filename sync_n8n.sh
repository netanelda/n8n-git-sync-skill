#!/usr/bin/env bash
#
# sync_n8n.sh — Fetch an n8n workflow JSON, strip secrets, and commit to Git.
# Usage: ./sync_n8n.sh <WORKFLOW_ID> "<TITLE>" ["<BODY>"]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOWS_DIR="$SCRIPT_DIR/n8n-workflows"
ID_MAP_FILE="$WORKFLOWS_DIR/.id-map.json"
GLOBAL_ENV="$HOME/.n8n-sync/.env"
PROJECT_ENV="$SCRIPT_DIR/.env"

# ── Validate arguments ──
if [ $# -lt 2 ]; then
  echo "Usage: $0 <WORKFLOW_ID> \"<TITLE>\" [\"<BODY>\"]"
  exit 1
fi

WORKFLOW_ID="$1"
COMMIT_TITLE="$2"
COMMIT_BODY="${3:-}"

# ── Load credentials: project .env first, then global ──
if [ -f "$PROJECT_ENV" ]; then
  source "$PROJECT_ENV"
elif [ -f "$GLOBAL_ENV" ]; then
  source "$GLOBAL_ENV"
else
  echo "Error: No credentials found."
  echo "  Option 1: Create $PROJECT_ENV with N8N_BASE_URL and N8N_API_KEY"
  echo "  Option 2: Create $GLOBAL_ENV (shared across all projects)"
  exit 1
fi

if [ -z "${N8N_BASE_URL:-}" ] || [ -z "${N8N_API_KEY:-}" ]; then
  echo "Error: N8N_BASE_URL and N8N_API_KEY must be set"
  exit 1
fi

N8N_BASE_URL="${N8N_BASE_URL%/}"

# ── Fetch workflow JSON from n8n API ──
echo "Fetching workflow $WORKFLOW_ID from $N8N_BASE_URL ..."

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$N8N_BASE_URL/api/v1/workflows/$WORKFLOW_ID")

HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -1)

if [ "$HTTP_STATUS" -ne 200 ]; then
  echo "Error: n8n API returned HTTP $HTTP_STATUS"
  echo "$HTTP_BODY"
  exit 1
fi

# ── Sanitize: strip credentials and secrets from JSON ──
# This removes actual credential data while preserving workflow structure.
# Credentials stay safe in n8n — Git is for tracking structure and logic only.
SANITIZED_JSON=$(echo "$HTTP_BODY" | jq '
  # Strip credential values from nodes (replace with type reference only)
  (.nodes // []) |= [.[] |
    if .credentials then
      .credentials = (.credentials | to_entries | map({
        key: .key,
        value: { "id": .value.id, "name": .value.name }
      }) | from_entries)
    else . end
  ] |
  # Remove staticData (can contain tokens, session data)
  del(.staticData) |
  # Remove sharedWithProjects (internal permissions)
  del(.sharedWithProjects) |
  # Scan all string values and redact anything that looks like a secret
  walk(
    if type == "string" then
      # Redact JWT tokens
      if test("^eyJ[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9_-]{20,}") then "[REDACTED_TOKEN]"
      # Redact long base64-like strings (likely keys/tokens, 40+ chars)
      elif test("^[A-Za-z0-9+/=_-]{40,}$") then "[REDACTED_KEY]"
      # Redact AWS access keys
      elif test("^AKIA[0-9A-Z]{16}$") then "[REDACTED_AWS_KEY]"
      # Redact strings starting with sk-, pk-, api_, key_
      elif test("^(sk-|pk-|api_|key_)[A-Za-z0-9]{20,}") then "[REDACTED_API_KEY]"
      else .
      end
    else .
    end
  )
')
echo "Sanitized credentials from workflow JSON"

# ── Extract workflow name and build filename ──
mkdir -p "$WORKFLOWS_DIR"

WORKFLOW_NAME=$(echo "$SANITIZED_JSON" | jq -r '.name // empty')
if [ -z "$WORKFLOW_NAME" ]; then
  echo "Warning: Could not extract workflow name, falling back to ID"
  SANITIZED_NAME="workflow-$WORKFLOW_ID"
else
  SANITIZED_NAME=$(echo "$WORKFLOW_NAME" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[_ ]/-/g' | \
    sed 's/[^a-z0-9-]//g' | \
    sed 's/--*/-/g' | \
    sed 's/^-//;s/-$//')
fi

NEW_FILENAME="${SANITIZED_NAME}.json"
OUTPUT_FILE="$WORKFLOWS_DIR/$NEW_FILENAME"

# ── Handle renames ──
if [ -f "$ID_MAP_FILE" ]; then
  OLD_FILENAME=$(jq -r --arg id "$WORKFLOW_ID" '.[$id] // empty' "$ID_MAP_FILE")
else
  OLD_FILENAME=""
fi

FILES_TO_ADD=()

if [ -n "$OLD_FILENAME" ] && [ "$OLD_FILENAME" != "$NEW_FILENAME" ]; then
  OLD_FILE="$WORKFLOWS_DIR/$OLD_FILENAME"
  if [ -f "$OLD_FILE" ]; then
    echo "Workflow renamed: $OLD_FILENAME → $NEW_FILENAME"
    cd "$SCRIPT_DIR"
    git mv "$OLD_FILE" "$OUTPUT_FILE" 2>/dev/null || mv "$OLD_FILE" "$OUTPUT_FILE"
    FILES_TO_ADD+=("$OUTPUT_FILE")
  fi
fi

# ── Save sanitized, pretty-printed JSON ──
echo "$SANITIZED_JSON" | jq '.' > "$OUTPUT_FILE"
echo "Saved to $OUTPUT_FILE"

# ── Update ID map ──
if [ -f "$ID_MAP_FILE" ]; then
  UPDATED_MAP=$(jq --arg id "$WORKFLOW_ID" --arg fn "$NEW_FILENAME" '. + {($id): $fn}' "$ID_MAP_FILE")
else
  UPDATED_MAP=$(jq -n --arg id "$WORKFLOW_ID" --arg fn "$NEW_FILENAME" '{($id): $fn}')
fi
echo "$UPDATED_MAP" | jq '.' > "$ID_MAP_FILE"

# ── Generate README index ──
README_FILE="$WORKFLOWS_DIR/README.md"
{
  echo "# Synced n8n Workflows"
  echo ""
  echo "> Credentials are stripped from these files. Secrets remain safe in n8n."
  echo ""
  echo "| Name | ID | Last Synced | File |"
  echo "|------|----|-------------|------|"

  for json_file in "$WORKFLOWS_DIR"/*.json; do
    [ -f "$json_file" ] || continue
    fname=$(basename "$json_file")
    [ "$fname" = ".id-map.json" ] && continue

    w_name=$(jq -r '.name // "Unknown"' "$json_file")
    w_id=$(jq -r '.id // "?"' "$json_file")
    w_synced=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$json_file" 2>/dev/null || date +"%Y-%m-%d %H:%M")
    echo "| $w_name | $w_id | $w_synced | [$fname]($fname) |"
  done
} > "$README_FILE"
echo "Updated workflow index at $README_FILE"

# ── Git commit and push ──
cd "$SCRIPT_DIR"
git add "$OUTPUT_FILE" "$ID_MAP_FILE" "$README_FILE"
for f in "${FILES_TO_ADD[@]+"${FILES_TO_ADD[@]}"}"; do
  git add "$f"
done

if git diff --cached --quiet; then
  echo "No changes detected — skipping commit."
  exit 0
fi

if [ -n "$COMMIT_BODY" ]; then
  git commit -m "$COMMIT_TITLE" -m "$COMMIT_BODY"
else
  git commit -m "$COMMIT_TITLE"
fi

git push origin HEAD
echo "Committed and pushed: $COMMIT_TITLE"
