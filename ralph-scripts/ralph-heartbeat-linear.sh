#!/usr/bin/env bash
# ralph-heartbeat-linear.sh - Post periodic heartbeat to Linear
#
# Call this every 10-15 minutes during long-running work
# to let the user know Claude is still alive
#
# Usage: ralph-heartbeat-linear.sh <issue-id> [message]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ralph-linear.sh" 2>/dev/null || true

ISSUE_ID="${1:-}"
MESSAGE="${2:-}"
STATE_FILE="${RALPH_STATE_FILE:-progress/session-state.json}"

if [[ -z "$ISSUE_ID" ]]; then
  echo "Usage: ralph-heartbeat-linear.sh <issue-id> [message]" >&2
  exit 1
fi

# Get current step from state if available
current_step=""
completed_count=0
if [[ -f "$STATE_FILE" ]]; then
  current_step=$(jq -r '.current_step // ""' "$STATE_FILE")
  completed_count=$(jq -r '.completed_steps | length' "$STATE_FILE")
  # Update heartbeat timestamp in state
  "$SCRIPT_DIR/ralph-state.sh" heartbeat >/dev/null 2>&1 || true
fi

# Build heartbeat message
now=$(date +"%H:%M:%S")
if [[ -n "$MESSAGE" ]]; then
  heartbeat_msg="💓 **Heartbeat** ($now)

$MESSAGE"
elif [[ -n "$current_step" ]]; then
  heartbeat_msg="💓 **Heartbeat** ($now)

**Working on:** $current_step
**Completed:** $completed_count steps

_Still making progress. Comment here if you need anything._"
else
  heartbeat_msg="💓 **Heartbeat** ($now)

_Still working. Comment here if you need anything._"
fi

# Post to Linear
add_comment "$ISSUE_ID" "$heartbeat_msg" >/dev/null

echo "Heartbeat posted at $now"
