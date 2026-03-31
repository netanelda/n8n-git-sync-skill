#!/usr/bin/env bash
#
# sync_all_n8n.sh — Fetch ALL n8n workflows and commit them to Git.
# Usage: ./sync_all_n8n.sh
#
# Useful for initial backup or periodic full snapshots.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOWS_DIR="$SCRIPT_DIR/n8n-workflows"
ID_MAP_FILE="$WORKFLOWS_DIR/.id-map.json"
GLOBAL_ENV="$HOME/.n8n-sync/.env"
PROJECT_ENV="$SCRIPT_DIR/.env"

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

# ── List all workflows ──
echo "Fetching workflow list from $N8N_BASE_URL ..."

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$N8N_BASE_URL/api/v1/workflows?limit=250")

HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -1)

if [ "$HTTP_STATUS" -ne 200 ]; then
  echo "Error: n8n API returned HTTP $HTTP_STATUS"
  echo "$HTTP_BODY"
  exit 1
fi

# Extract workflow IDs from the list response
WORKFLOW_IDS=$(echo "$HTTP_BODY" | jq -r '.data[].id')
TOTAL=$(echo "$WORKFLOW_IDS" | wc -l | tr -d ' ')
echo "Found $TOTAL workflows."

mkdir -p "$WORKFLOWS_DIR"

# Initialize or load existing ID map
if [ -f "$ID_MAP_FILE" ]; then
  ID_MAP=$(cat "$ID_MAP_FILE")
else
  ID_MAP="{}"
fi

COUNT=0

# ── Fetch each workflow ──
for WID in $WORKFLOW_IDS; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL] Fetching workflow $WID ..."

  WF_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    "$N8N_BASE_URL/api/v1/workflows/$WID")

  WF_BODY=$(echo "$WF_RESPONSE" | sed '$d')
  WF_STATUS=$(echo "$WF_RESPONSE" | tail -1)

  if [ "$WF_STATUS" -ne 200 ]; then
    echo "  Warning: HTTP $WF_STATUS for workflow $WID — skipping"
    continue
  fi

  # Extract and sanitize name
  WF_NAME=$(echo "$WF_BODY" | jq -r '.name // empty')
  if [ -z "$WF_NAME" ]; then
    SANITIZED="workflow-$WID"
  else
    SANITIZED=$(echo "$WF_NAME" | \
      tr '[:upper:]' '[:lower:]' | \
      sed 's/[_ ]/-/g' | \
      sed 's/[^a-z0-9-]//g' | \
      sed 's/--*/-/g' | \
      sed 's/^-//;s/-$//')
  fi

  FILENAME="${SANITIZED}.json"

  # Handle renames
  OLD_FN=$(echo "$ID_MAP" | jq -r --arg id "$WID" '.[$id] // empty')
  if [ -n "$OLD_FN" ] && [ "$OLD_FN" != "$FILENAME" ]; then
    OLD_PATH="$WORKFLOWS_DIR/$OLD_FN"
    if [ -f "$OLD_PATH" ]; then
      echo "  Renamed: $OLD_FN → $FILENAME"
      cd "$SCRIPT_DIR"
      git mv "$OLD_PATH" "$WORKFLOWS_DIR/$FILENAME" 2>/dev/null || mv "$OLD_PATH" "$WORKFLOWS_DIR/$FILENAME"
    fi
  fi

  echo "$WF_BODY" | jq '.' > "$WORKFLOWS_DIR/$FILENAME"
  ID_MAP=$(echo "$ID_MAP" | jq --arg id "$WID" --arg fn "$FILENAME" '. + {($id): $fn}')
  echo "  → $FILENAME"
done

# ── Save ID map ──
echo "$ID_MAP" | jq '.' > "$ID_MAP_FILE"

# ── Generate README index ──
README_FILE="$WORKFLOWS_DIR/README.md"
{
  echo "# Synced n8n Workflows"
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

# ── Git commit and push ──
cd "$SCRIPT_DIR"
git add "$WORKFLOWS_DIR"

if git diff --cached --quiet; then
  echo "No changes detected — nothing to commit."
  exit 0
fi

git commit -m "Bulk sync: $COUNT workflows" -m "Full snapshot of all $COUNT n8n workflows from $N8N_BASE_URL"
git push origin HEAD
echo "Done! Synced $COUNT workflows."
