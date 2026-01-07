#!/usr/bin/env bash
# ralph-resume.sh - Resume from a saved session state
#
# Outputs a prompt that tells Claude how to resume work
#
# Usage: ralph-resume.sh [state-file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${1:-progress/session-state.json}"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "No session to resume. State file not found: $STATE_FILE"
  exit 1
fi

# Check if session is resumable
status=$(jq -r '.status' "$STATE_FILE")
if [[ "$status" == "completed" ]]; then
  echo "Session already completed. Nothing to resume."
  exit 0
fi

# Extract session details
issue_id=$(jq -r '.issue_id' "$STATE_FILE")
task=$(jq -r '.task' "$STATE_FILE")
current_step=$(jq -r '.current_step // "Unknown"' "$STATE_FILE")
last_updated=$(jq -r '.last_updated' "$STATE_FILE")
completed_steps=$(jq -r '.completed_steps | length' "$STATE_FILE")
pending_steps=$(jq -r '.pending_steps | join(", ")' "$STATE_FILE")
completed_list=$(jq -r '.completed_steps | join("\n  - ")' "$STATE_FILE")

# Calculate time since last update
last_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_updated" +%s 2>/dev/null || date -d "$last_updated" +%s)
now_ts=$(date +%s)
hours_ago=$(( (now_ts - last_ts) / 3600 ))
mins_ago=$(( ((now_ts - last_ts) % 3600) / 60 ))

cat << EOF
# 🔄 SESSION RECOVERY

A previous session was interrupted. Here's what was happening:

## Task
**Issue:** $issue_id
**Description:** $task

## Progress When Interrupted
**Last Step:** $current_step
**Status:** $status
**Last Update:** ${hours_ago}h ${mins_ago}m ago

## Completed Steps ($completed_steps)
EOF

if [[ -n "$completed_list" && "$completed_list" != "" ]]; then
  echo "  - $completed_list"
else
  echo "  (none yet)"
fi

cat << EOF

## Pending Steps
EOF

if [[ -n "$pending_steps" && "$pending_steps" != "" ]]; then
  echo "  $pending_steps"
else
  echo "  (not specified)"
fi

cat << EOF

## Resume Instructions

1. Source environment: \`source ~/.zshrc\`
2. Post recovery notice to Linear:
   \`\`\`bash
   ./ralph-scripts/ralph-linear.sh comment "$issue_id" "🔄 **Session Resumed**

   Previous session interrupted ${hours_ago}h ${mins_ago}m ago.
   Last step: $current_step
   Completed: $completed_steps steps

   Continuing work now..."
   \`\`\`
3. Continue from: **$current_step**
4. Check for any user comments since last update

## State File
\`$STATE_FILE\`

---
**To continue, pick up from "$current_step" and keep going.**
EOF
