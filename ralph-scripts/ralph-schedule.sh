#!/usr/bin/env bash
# ralph-schedule.sh - Self-scheduling capability for agents
# Agents can schedule their own wake-ups and check-ins
#
# Inspired by Tmux Orchestrator's self-triggering pattern
# Uses a simple file-based scheduler (no cron dependency)

set -euo pipefail

# Only source config if not already sourced
if [[ -z "${RALPH_DIR:-}" ]]; then
  source "$(dirname "$0")/ralph-config.sh"
fi

# =============================================================================
# SCHEDULER CONFIGURATION
# =============================================================================

SCHEDULE_DIR="${PROGRESS_DIR}/schedule"
SCHEDULE_LOG="${PROGRESS_DIR}/schedule.log"

mkdir -p "$SCHEDULE_DIR"

# =============================================================================
# SCHEDULING FUNCTIONS
# =============================================================================

# Schedule a wake-up call for an agent
# Usage: schedule_wakeup <agent_id> <delay_seconds> <note>
schedule_wakeup() {
  local agent_id="$1"
  local delay="$2"
  local note="${3:-scheduled check-in}"

  local wake_time=$(($(date +%s) + delay))
  local schedule_file="$SCHEDULE_DIR/${agent_id}_${wake_time}.json"

  cat > "$schedule_file" << EOF
{
  "agent_id": "$agent_id",
  "wake_time": $wake_time,
  "wake_time_human": "$(date -r $wake_time -Iseconds 2>/dev/null || date -d @$wake_time -Iseconds)",
  "note": "$note",
  "created_at": "$(date -Iseconds)",
  "status": "pending"
}
EOF

  log_debug "Scheduled wake-up for $agent_id in ${delay}s: $note"
  echo "$schedule_file"
}

# Shorthand for common intervals
# Usage: schedule_with_note <minutes> <note>
schedule_with_note() {
  local minutes="$1"
  local note="$2"
  local agent_id="${AGENT_ID:-agent-1}"

  schedule_wakeup "$agent_id" $((minutes * 60)) "$note"
}

# Check if agent has any due wake-ups
# Usage: check_schedule <agent_id>
# Returns: 0 if wake-up due, 1 if nothing due
check_schedule() {
  local agent_id="$1"
  local now=$(date +%s)

  for schedule_file in "$SCHEDULE_DIR"/${agent_id}_*.json; do
    [[ -f "$schedule_file" ]] || continue

    local status=$(jq -r '.status' "$schedule_file")
    [[ "$status" != "pending" ]] && continue

    local wake_time=$(jq -r '.wake_time' "$schedule_file")

    if [[ $now -ge $wake_time ]]; then
      local note=$(jq -r '.note' "$schedule_file")

      # Mark as triggered
      jq '.status = "triggered"' "$schedule_file" > "${schedule_file}.tmp" \
        && mv "${schedule_file}.tmp" "$schedule_file"

      echo "$note"
      return 0
    fi
  done

  return 1
}

# Get all pending schedules for an agent
# Usage: get_schedules <agent_id>
get_schedules() {
  local agent_id="$1"

  echo "=== Scheduled wake-ups for $agent_id ==="
  for schedule_file in "$SCHEDULE_DIR"/${agent_id}_*.json; do
    [[ -f "$schedule_file" ]] || continue

    local status=$(jq -r '.status' "$schedule_file")
    [[ "$status" != "pending" ]] && continue

    jq -r '"  \(.wake_time_human): \(.note)"' "$schedule_file"
  done
}

# Cancel all pending schedules for an agent
# Usage: cancel_schedules <agent_id>
cancel_schedules() {
  local agent_id="$1"

  for schedule_file in "$SCHEDULE_DIR"/${agent_id}_*.json; do
    [[ -f "$schedule_file" ]] || continue
    jq '.status = "cancelled"' "$schedule_file" > "${schedule_file}.tmp" \
      && mv "${schedule_file}.tmp" "$schedule_file"
  done

  log_debug "Cancelled all schedules for $agent_id"
}

# Clean up old schedule files
cleanup_schedules() {
  local retention=86400  # Keep for 24 hours
  local now=$(date +%s)

  for schedule_file in "$SCHEDULE_DIR"/*.json; do
    [[ -f "$schedule_file" ]] || continue

    local wake_time=$(jq -r '.wake_time' "$schedule_file")
    local age=$((now - wake_time))

    if [[ $age -gt $retention ]]; then
      rm -f "$schedule_file"
    fi
  done
}

# =============================================================================
# SCHEDULER DAEMON
# =============================================================================

# Run the scheduler daemon
# Checks for due wake-ups and sends messages to agents
run_scheduler() {
  log "=== Scheduler daemon starting ==="

  while true; do
    local now=$(date +%s)

    for schedule_file in "$SCHEDULE_DIR"/*.json; do
      [[ -f "$schedule_file" ]] || continue

      local status=$(jq -r '.status' "$schedule_file")
      [[ "$status" != "pending" ]] && continue

      local wake_time=$(jq -r '.wake_time' "$schedule_file")

      if [[ $now -ge $wake_time ]]; then
        local agent_id=$(jq -r '.agent_id' "$schedule_file")
        local note=$(jq -r '.note' "$schedule_file")

        # Mark as triggered
        jq '.status = "triggered"' "$schedule_file" > "${schedule_file}.tmp" \
          && mv "${schedule_file}.tmp" "$schedule_file"

        # Log the wake-up
        echo "$(date -Iseconds) WAKEUP $agent_id: $note" >> "$SCHEDULE_LOG"

        # Send message to agent
        source "$(dirname "$0")/ralph-message.sh"
        send_message "$agent_id" "WAKEUP:$note" "scheduler"

        log "Triggered wake-up for $agent_id: $note"
      fi
    done

    # Periodic cleanup
    cleanup_schedules

    sleep 10
  done
}

# =============================================================================
# SELF-SCHEDULING HELPERS
# =============================================================================

# Schedule next iteration (for use within agents)
# Usage: schedule_next <reason>
schedule_next() {
  local reason="$1"
  local delay="${2:-300}"  # Default 5 minutes
  local agent_id="${AGENT_ID:-agent-1}"

  schedule_wakeup "$agent_id" "$delay" "$reason"
  log_debug "Agent $agent_id scheduled next check-in in ${delay}s: $reason"
}

# Schedule for after current task
# Usage: schedule_after_task <task_description>
schedule_after_task() {
  local task="$1"
  local agent_id="${AGENT_ID:-agent-1}"

  # Short delay to allow task completion check
  schedule_wakeup "$agent_id" 60 "Check completion of: $task"
}

# Schedule daily standup
# Usage: schedule_daily_standup <hour> <minute>
schedule_daily_standup() {
  local hour="${1:-9}"
  local minute="${2:-0}"
  local agent_id="${AGENT_ID:-agent-1}"

  # Calculate seconds until next occurrence
  local now=$(date +%s)
  local today_standup=$(date -v${hour}H -v${minute}M -v0S +%s 2>/dev/null || \
    date -d "today $hour:$minute:00" +%s)

  local delay
  if [[ $today_standup -gt $now ]]; then
    delay=$((today_standup - now))
  else
    # Schedule for tomorrow
    delay=$((today_standup + 86400 - now))
  fi

  schedule_wakeup "$agent_id" "$delay" "Daily standup"
}

# =============================================================================
# CLI
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-help}" in
    schedule)
      schedule_wakeup "$2" "$3" "${4:-check-in}"
      ;;
    check)
      if note=$(check_schedule "$2"); then
        echo "WAKE-UP: $note"
      else
        echo "No pending wake-ups"
      fi
      ;;
    list)
      get_schedules "$2"
      ;;
    cancel)
      cancel_schedules "$2"
      echo "Cancelled all schedules for $2"
      ;;
    daemon)
      run_scheduler
      ;;
    cleanup)
      cleanup_schedules
      echo "Cleaned up old schedules"
      ;;
    help|*)
      echo "Usage: $0 {schedule|check|list|cancel|daemon|cleanup}"
      echo ""
      echo "Commands:"
      echo "  schedule <agent_id> <delay_sec> [note] - Schedule wake-up"
      echo "  check <agent_id>                       - Check for due wake-ups"
      echo "  list <agent_id>                        - List pending schedules"
      echo "  cancel <agent_id>                      - Cancel all schedules"
      echo "  daemon                                 - Run scheduler daemon"
      echo "  cleanup                                - Remove old schedules"
      echo ""
      echo "Example:"
      echo "  $0 schedule agent-1 300 'Check PR status'"
      echo "  $0 check agent-1"
      ;;
  esac
fi

# Export functions for sourcing
export -f schedule_wakeup schedule_with_note check_schedule get_schedules cancel_schedules schedule_next schedule_after_task
