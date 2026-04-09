#!/usr/bin/env bash
#
# copy-claude-home.sh — selective copy of ~/.claude (+ ~/.claude.json) into a temp dir
#
# Usage:
#   copy-claude-home.sh <dest-dir>
#
# Writes:
#   <dest-dir>/.claude/             selective subset of $HOME/.claude
#   <dest-dir>/.claude.json         copy of $HOME/.claude.json
#
# This is a whitelist copy. See the plan in ~/.claude/plans/graceful-giggling-swan.md
# for the rationale. The container mounts this copy (not the real ~/.claude), so:
#   - The container gets settings.json, skills/, commands/, agents/, plugins/, CLAUDE.md
#   - Host state (projects/, todos/, sessions/, history.jsonl, etc.) is NOT leaked
#   - Writes from the container cannot affect the host

set -euo pipefail

DEST="${1:?usage: copy-claude-home.sh <dest-dir>}"
SRC_CLAUDE="$HOME/.claude"
SRC_CLAUDE_JSON="$HOME/.claude.json"

if [[ ! -d "$SRC_CLAUDE" ]]; then
  echo "ERROR: \$HOME/.claude not found at $SRC_CLAUDE" >&2
  exit 1
fi

if [[ ! -f "$SRC_CLAUDE_JSON" ]]; then
  echo "ERROR: \$HOME/.claude.json not found at $SRC_CLAUDE_JSON" >&2
  exit 1
fi

mkdir -p "$DEST/.claude"

# Whitelisted top-level items under ~/.claude
WHITELIST=(
  ".credentials.json"
  "settings.json"
  "settings.local.json"
  "CLAUDE.md"
  "skills"
  "commands"
  "agents"
  "plugins"
)

copied_count=0
for item in "${WHITELIST[@]}"; do
  src="$SRC_CLAUDE/$item"
  if [[ -e "$src" ]]; then
    # -a preserves permissions/timestamps; critical for .credentials.json (0600)
    cp -a "$src" "$DEST/.claude/"
    copied_count=$((copied_count + 1))
  fi
done

# Copy .claude.json from $HOME
cp -a "$SRC_CLAUDE_JSON" "$DEST/.claude.json"

echo "Copied $copied_count items from $SRC_CLAUDE + .claude.json → $DEST"
