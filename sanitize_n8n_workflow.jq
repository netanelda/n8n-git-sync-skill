# sanitize_n8n_workflow.jq — Used by sync_n8n.sh
# Strips credential secrets but PRESERVES resource identifiers (file/sheet/folder IDs)
# that are not secrets (Google Drive/Sheets, Slack, Monday, Notion, etc.)

def key_in($k; $arr): ($arr | index($k)) != null;

# Keys used as n8n resource-locator parents (.../<key>/value)
def rl_parent_keys:
  ["documentId","fileId","folderId","driveId","sheetId","spreadsheetId",
   "resourceId","databaseId","listId","siteId","teamId","channelId",
   "chatId","threadId","itemId","boardId","workspaceId","pageId",
   "presentationId","formId","attachmentId","calendarId","tableId",
   "baseId","viewId","docId","deckId","nodeId","workflowId",
   "blockId","messageId","conversationId","repositoryId","projectId"];

# Keys where the string leaf itself is a resource id (flat param)
def flat_resource_keys:
  ["spreadsheetId","sheetId","documentId","fileId","folderId","driveId",
   "resourceId","databaseId","siteId","teamId","channelId","chatId",
   "threadId","itemId","boardId","workspaceId","pageId","presentationId",
   "formId","attachmentId","calendarId","tableId","baseId","viewId",
   "docId","deckId","nodeId","workflowId","executionId","blockId",
   "messageId","conversationId","repositoryId","projectId"];

# Path ends with .../<resourceKey>/value (Google __rl pattern and similar)
def is_rl_value_path($p):
  ($p | length) as $len
  | $len >= 2
  and ($p[$len - 1] == "value")
  and ($p[$len - 2] | type == "string")
  and ($p[$len - 2] as $k | key_in($k; rl_parent_keys));

# Scalar sits directly under a key that holds an external resource id
def is_flat_resource_id_key($p):
  ($p | length) as $len
  | $len >= 1
  and ($p[$len - 1] | type == "string")
  and ($p[$len - 1] as $k | key_in($k; flat_resource_keys));

def is_resource_identifier_path($p):
  is_rl_value_path($p) or is_flat_resource_id_key($p);

def is_webhook_path($p):
  ($p | length) as $len
  | $len >= 1
  and ($p[$len - 1] == "path")
  and (($len >= 2 and $p[$len - 2] == "parameters") or
       ($len >= 3 and $p[$len - 3] == "parameters"));

def redact_string_at_path($p; $s):
  if is_resource_identifier_path($p) then $s
  elif is_webhook_path($p) then $s
  elif $s | test("^eyJ[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9_-]{20,}") then "[REDACTED_TOKEN]"
  elif $s | test("^AKIA[0-9A-Z]{16}$") then "[REDACTED_AWS_KEY]"
  elif $s | test("^(sk-|pk-|api_|key_)[A-Za-z0-9]{20,}") then "[REDACTED_API_KEY]"
  elif $s | test("^[A-Za-z0-9+/=_-]{40,}$") then "[REDACTED_KEY]"
  else $s end;

# Main transform
(.nodes // []) |= [.[] |
  if .credentials then
    .credentials = (.credentials | to_entries | map({
      key: .key,
      value: { "id": .value.id, "name": .value.name }
    }) | from_entries)
  else . end
] |
del(.staticData) |
del(.sharedWithProjects) |
reduce paths(scalars) as $p (
  .;
  getpath($p) as $v
  | if ($v | type) == "string" then
      setpath($p; redact_string_at_path($p; $v))
    else . end
)
