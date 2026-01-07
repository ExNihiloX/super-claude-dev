#!/usr/bin/env bash
# ralph-poll-loop.sh - Loop polling until response received
# Auto-approved when called as ./ralph-scripts/ralph-poll-loop.sh

# Don't use set -e here - we need to handle errors gracefully
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source ralph-linear.sh but override its set -e
source "$SCRIPT_DIR/ralph-linear.sh"
set +e  # Disable exit-on-error after sourcing

ISSUE_ID="${1:-}"
SINCE="${2:-}"
MAX_ITERATIONS="${3:-180}"  # 180 × 2 min = 6 hours
POLL_TIMEOUT="${4:-120}"    # 2 minutes per poll
POLL_INTERVAL="${5:-30}"    # 30 sec between checks within poll

if [[ -z "$ISSUE_ID" || -z "$SINCE" ]]; then
  echo "Usage: ralph-poll-loop.sh <issue-id> <since-timestamp> [max-iterations] [poll-timeout] [poll-interval]" >&2
  exit 1
fi

echo "Starting poll loop for issue $ISSUE_ID" >&2
echo "Max iterations: $MAX_ITERATIONS (timeout: ${POLL_TIMEOUT}s each)" >&2
echo "Waiting for response since: $SINCE" >&2
echo "---" >&2

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "[$(date '+%H:%M:%S')] Poll attempt $i/$MAX_ITERATIONS" >&2

    # Get comments since timestamp
    comments=""
    comments=$(get_comments "$ISSUE_ID" "$SINCE" 2>/dev/null) || {
        echo "  Warning: get_comments failed, retrying..." >&2
        sleep "$POLL_INTERVAL"
        continue
    }

    # Check if we got valid JSON
    if ! echo "$comments" | jq empty 2>/dev/null; then
        echo "  Warning: Invalid JSON response, retrying..." >&2
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Count comments
    count=$(echo "$comments" | jq 'length' 2>/dev/null) || count=0

    if [[ "$count" -gt 0 && "$count" != "0" ]]; then
        echo "---" >&2
        echo "RESPONSE_RECEIVED" >&2
        # Output the first comment as JSON to stdout (not stderr)
        echo "$comments" | jq -r '.[0]'
        exit 0
    fi

    echo "  No new comments yet, waiting ${POLL_INTERVAL}s..." >&2
    sleep "$POLL_INTERVAL"
done

echo "---" >&2
echo "MAX_ITERATIONS_REACHED" >&2
exit 1
