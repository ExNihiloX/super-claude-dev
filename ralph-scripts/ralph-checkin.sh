#!/usr/bin/env bash
# ralph-checkin.sh - Check for new comments/messages from the user
# Run this periodically during work to catch user interrupts
#
# Usage: ralph-checkin.sh <issue-id> <since-timestamp>
# Returns: New comment JSON if found, empty if none

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ralph-linear.sh" 2>/dev/null || true

ISSUE_ID="${1:-}"
SINCE="${2:-}"

if [[ -z "$ISSUE_ID" ]]; then
  echo "Usage: ralph-checkin.sh <issue-id> <since-timestamp>" >&2
  exit 1
fi

# If no since timestamp, use 5 minutes ago
if [[ -z "$SINCE" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    SINCE=$(date -u -v-5M +"%Y-%m-%dT%H:%M:%SZ")
  else
    SINCE=$(date -u -d "5 minutes ago" +"%Y-%m-%dT%H:%M:%SZ")
  fi
fi

# Check for new comments
comments=$(get_comments "$ISSUE_ID" "$SINCE" 2>/dev/null) || comments="[]"
count=$(echo "$comments" | jq 'length' 2>/dev/null || echo "0")

if [[ "$count" -gt 0 ]]; then
  # Return the most recent comment
  echo "$comments" | jq -r '.[-1]'
  exit 0
else
  # No new comments
  exit 1
fi
