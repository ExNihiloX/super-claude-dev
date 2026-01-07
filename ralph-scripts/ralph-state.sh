#!/usr/bin/env bash
# ralph-state.sh - State persistence for autonomous sessions
#
# Saves/loads session state so work can resume if Claude crashes
#
# Usage:
#   ralph-state.sh init <issue-id> <task-description>
#   ralph-state.sh save <key> <value>
#   ralph-state.sh get <key>
#   ralph-state.sh load
#   ralph-state.sh update-progress <status> <message>
#   ralph-state.sh heartbeat
#   ralph-state.sh clear

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${RALPH_STATE_FILE:-progress/session-state.json}"

# Ensure progress directory exists
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

# =============================================================================
# STATE OPERATIONS
# =============================================================================

# Initialize a new session state
init_state() {
  local issue_id="$1"
  local task_description="$2"

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat > "$STATE_FILE" << EOF
{
  "version": "1.0",
  "issue_id": "$issue_id",
  "task": "$task_description",
  "status": "in_progress",
  "started_at": "$now",
  "last_updated": "$now",
  "last_heartbeat": "$now",
  "last_checkin": "$now",
  "current_step": "",
  "completed_steps": [],
  "pending_steps": [],
  "context": {},
  "history": []
}
EOF

  echo "State initialized for issue $issue_id"
}

# Save a key-value pair to state
save_value() {
  local key="$1"
  local value="$2"

  if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: No state file. Run 'init' first." >&2
    return 1
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Update the value and last_updated timestamp
  local tmp
  tmp=$(mktemp)
  jq --arg key "$key" --arg value "$value" --arg now "$now" \
    '.[$key] = $value | .last_updated = $now' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

# Get a value from state
get_value() {
  local key="$1"

  if [[ ! -f "$STATE_FILE" ]]; then
    echo ""
    return 1
  fi

  jq -r --arg key "$key" '.[$key] // empty' "$STATE_FILE"
}

# Load full state as JSON
load_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "{}"
    return 1
  fi

  cat "$STATE_FILE"
}

# Update progress with status and message
update_progress() {
  local status="$1"
  local message="$2"

  if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: No state file. Run 'init' first." >&2
    return 1
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Add to history and update current step
  local tmp
  tmp=$(mktemp)
  jq --arg status "$status" --arg message "$message" --arg now "$now" \
    '.status = $status |
     .current_step = $message |
     .last_updated = $now |
     .history += [{"timestamp": $now, "status": $status, "message": $message}]' \
    "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"

  echo "Progress: $status - $message"
}

# Mark a step as completed
complete_step() {
  local step="$1"

  if [[ ! -f "$STATE_FILE" ]]; then
    return 1
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp)
  jq --arg step "$step" --arg now "$now" \
    '.completed_steps += [$step] | .last_updated = $now' \
    "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

# Add pending steps
add_pending_steps() {
  local steps="$1"  # JSON array

  if [[ ! -f "$STATE_FILE" ]]; then
    return 1
  fi

  local tmp
  tmp=$(mktemp)
  jq --argjson steps "$steps" \
    '.pending_steps = $steps' \
    "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

# Update heartbeat timestamp
heartbeat() {
  if [[ ! -f "$STATE_FILE" ]]; then
    return 1
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp)
  jq --arg now "$now" '.last_heartbeat = $now' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"

  echo "$now"
}

# Update last checkin timestamp
update_checkin() {
  if [[ ! -f "$STATE_FILE" ]]; then
    return 1
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp)
  jq --arg now "$now" '.last_checkin = $now' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"

  echo "$now"
}

# Save context data (arbitrary JSON)
save_context() {
  local key="$1"
  local value="$2"

  if [[ ! -f "$STATE_FILE" ]]; then
    return 1
  fi

  local tmp
  tmp=$(mktemp)
  jq --arg key "$key" --arg value "$value" \
    '.context[$key] = $value' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

# Get context data
get_context() {
  local key="$1"

  if [[ ! -f "$STATE_FILE" ]]; then
    echo ""
    return 1
  fi

  jq -r --arg key "$key" '.context[$key] // empty' "$STATE_FILE"
}

# Clear state (mark session complete)
clear_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    return 0
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp)
  jq --arg now "$now" \
    '.status = "completed" | .completed_at = $now' \
    "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"

  # Archive the state
  local archive_name="progress/session-$(date +%Y%m%d-%H%M%S).json"
  mv "$STATE_FILE" "$archive_name"
  echo "Session archived to $archive_name"
}

# Check if there's a recoverable session
has_session() {
  if [[ -f "$STATE_FILE" ]]; then
    local status
    status=$(jq -r '.status' "$STATE_FILE")
    if [[ "$status" == "in_progress" || "$status" == "blocked" ]]; then
      echo "true"
      return 0
    fi
  fi
  echo "false"
  return 1
}

# Get session summary for resume
session_summary() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "No session to resume"
    return 1
  fi

  jq -r '
    "Issue: \(.issue_id)\n" +
    "Task: \(.task)\n" +
    "Status: \(.status)\n" +
    "Current Step: \(.current_step)\n" +
    "Started: \(.started_at)\n" +
    "Last Updated: \(.last_updated)\n" +
    "Completed Steps: \(.completed_steps | length)\n" +
    "Pending Steps: \(.pending_steps | length)"
  ' "$STATE_FILE"
}

# =============================================================================
# CLI
# =============================================================================

case "${1:-help}" in
  init)
    if [[ -z "${2:-}" || -z "${3:-}" ]]; then
      echo "Usage: $0 init <issue-id> <task-description>" >&2
      exit 1
    fi
    init_state "$2" "$3"
    ;;
  save)
    if [[ -z "${2:-}" || -z "${3:-}" ]]; then
      echo "Usage: $0 save <key> <value>" >&2
      exit 1
    fi
    save_value "$2" "$3"
    ;;
  get)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 get <key>" >&2
      exit 1
    fi
    get_value "$2"
    ;;
  load)
    load_state
    ;;
  progress)
    if [[ -z "${2:-}" || -z "${3:-}" ]]; then
      echo "Usage: $0 progress <status> <message>" >&2
      exit 1
    fi
    update_progress "$2" "$3"
    ;;
  complete)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 complete <step-name>" >&2
      exit 1
    fi
    complete_step "$2"
    ;;
  pending)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 pending '<json-array>'" >&2
      exit 1
    fi
    add_pending_steps "$2"
    ;;
  heartbeat)
    heartbeat
    ;;
  checkin)
    update_checkin
    ;;
  context-save)
    if [[ -z "${2:-}" || -z "${3:-}" ]]; then
      echo "Usage: $0 context-save <key> <value>" >&2
      exit 1
    fi
    save_context "$2" "$3"
    ;;
  context-get)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 context-get <key>" >&2
      exit 1
    fi
    get_context "$2"
    ;;
  clear)
    clear_state
    ;;
  has-session)
    has_session
    ;;
  summary)
    session_summary
    ;;
  help|*)
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  init <issue-id> <task>  - Start new session"
    echo "  save <key> <value>      - Save key-value pair"
    echo "  get <key>               - Get value by key"
    echo "  load                    - Load full state JSON"
    echo "  progress <status> <msg> - Update progress"
    echo "  complete <step>         - Mark step completed"
    echo "  pending '<json-array>'  - Set pending steps"
    echo "  heartbeat               - Update heartbeat timestamp"
    echo "  checkin                 - Update checkin timestamp"
    echo "  context-save <k> <v>    - Save context data"
    echo "  context-get <key>       - Get context data"
    echo "  clear                   - Mark session complete & archive"
    echo "  has-session             - Check if recoverable session exists"
    echo "  summary                 - Show session summary"
    ;;
esac
