#!/usr/bin/env bash
# ralph-message.sh - Inter-agent messaging system
# Enables agents to communicate with each other
#
# Message queue is file-based for simplicity and debugging
# Each agent has an inbox: progress/messages/<agent-id>/
# Messages are JSON files with timestamp-based names

set -euo pipefail

# Only source config if not already sourced
if [[ -z "${RALPH_DIR:-}" ]]; then
  source "$(dirname "$0")/ralph-config.sh"
fi

# =============================================================================
# MESSAGE CONFIGURATION
# =============================================================================

MESSAGE_DIR="${PROGRESS_DIR}/messages"
MESSAGE_TTL=3600  # Messages expire after 1 hour

# =============================================================================
# MESSAGE FUNCTIONS
# =============================================================================

# Initialize messaging for an agent
init_messaging() {
  local agent_id="$1"
  mkdir -p "$MESSAGE_DIR/$agent_id"
}

# Send a message to another agent
# Usage: send_message <target_agent_id> <message>
send_message() {
  local target="$1"
  local message="$2"
  local sender="${3:-${AGENT_ID:-orchestrator}}"

  mkdir -p "$MESSAGE_DIR/$target"

  local timestamp=$(date +%s%N)
  local message_file="$MESSAGE_DIR/$target/${timestamp}.json"

  cat > "$message_file" << EOF
{
  "from": "$sender",
  "to": "$target",
  "message": "$message",
  "timestamp": "$(date -Iseconds)",
  "read": false
}
EOF

  log_debug "Message sent: $sender → $target: $message"
  return 0
}

# Receive all unread messages for an agent
# Usage: receive_messages <agent_id>
# Returns: newline-separated list of messages
receive_messages() {
  local agent_id="$1"
  local inbox="$MESSAGE_DIR/$agent_id"

  if [[ ! -d "$inbox" ]]; then
    return 0
  fi

  # Find all unread messages
  local messages=""
  for msg_file in "$inbox"/*.json; do
    [[ -f "$msg_file" ]] || continue

    local is_read=$(jq -r '.read' "$msg_file" 2>/dev/null || echo "true")

    if [[ "$is_read" == "false" ]]; then
      local content=$(jq -r '.message' "$msg_file")
      messages+="$content"$'\n'

      # Mark as read
      jq '.read = true' "$msg_file" > "${msg_file}.tmp" && mv "${msg_file}.tmp" "$msg_file"
    fi
  done

  # Clean up old messages
  cleanup_old_messages "$agent_id"

  echo -n "$messages"
}

# Peek at messages without marking as read
# Usage: peek_messages <agent_id>
peek_messages() {
  local agent_id="$1"
  local inbox="$MESSAGE_DIR/$agent_id"

  if [[ ! -d "$inbox" ]]; then
    echo "No messages"
    return 0
  fi

  echo "=== Messages for $agent_id ==="
  for msg_file in "$inbox"/*.json; do
    [[ -f "$msg_file" ]] || continue
    jq -r '"[\(.timestamp)] \(.from) → \(.to): \(.message) [read: \(.read)]"' "$msg_file"
  done
}

# Wait for a specific message type
# Usage: wait_for_message <agent_id> <message_pattern> <timeout_seconds>
wait_for_message() {
  local agent_id="$1"
  local pattern="$2"
  local timeout="${3:-60}"

  local waited=0
  while [[ $waited -lt $timeout ]]; do
    local messages
    messages=$(receive_messages "$agent_id")

    if echo "$messages" | grep -q "$pattern"; then
      echo "$messages" | grep "$pattern" | head -1
      return 0
    fi

    sleep 2
    waited=$((waited + 2))
  done

  return 1  # Timeout
}

# Broadcast message to all agents of a type
# Usage: broadcast_message <agent_type> <message>
# agent_type can be: pm, engineer, all
broadcast_message() {
  local agent_type="$1"
  local message="$2"
  local sender="${3:-orchestrator}"

  case "$agent_type" in
    pm)
      for inbox in "$MESSAGE_DIR"/pm-*; do
        [[ -d "$inbox" ]] || continue
        local target=$(basename "$inbox")
        send_message "$target" "$message" "$sender"
      done
      ;;
    engineer|agent)
      for inbox in "$MESSAGE_DIR"/agent-*; do
        [[ -d "$inbox" ]] || continue
        local target=$(basename "$inbox")
        send_message "$target" "$message" "$sender"
      done
      ;;
    all)
      for inbox in "$MESSAGE_DIR"/*; do
        [[ -d "$inbox" ]] || continue
        local target=$(basename "$inbox")
        send_message "$target" "$message" "$sender"
      done
      ;;
  esac
}

# Request-response pattern
# Usage: request <target> <message> <timeout>
# Returns the response or empty on timeout
request() {
  local target="$1"
  local message="$2"
  local timeout="${3:-30}"
  local request_id="req-$(date +%s%N)"
  local sender="${AGENT_ID:-orchestrator}"

  # Send request with ID
  send_message "$target" "REQUEST:$request_id:$message" "$sender"

  # Wait for response
  local response
  response=$(wait_for_message "$sender" "RESPONSE:$request_id:" "$timeout")

  if [[ -n "$response" ]]; then
    echo "${response#*RESPONSE:$request_id:}"
    return 0
  fi

  return 1
}

# Respond to a request
# Usage: respond <request_id> <requester> <response>
respond() {
  local request_id="$1"
  local requester="$2"
  local response="$3"

  send_message "$requester" "RESPONSE:$request_id:$response"
}

# Clean up old messages
cleanup_old_messages() {
  local agent_id="$1"
  local inbox="$MESSAGE_DIR/$agent_id"
  local now=$(date +%s)

  for msg_file in "$inbox"/*.json; do
    [[ -f "$msg_file" ]] || continue

    local msg_time=$(jq -r '.timestamp' "$msg_file" | xargs -I{} date -j -f "%Y-%m-%dT%H:%M:%S" "{}" +%s 2>/dev/null || echo 0)
    local age=$((now - msg_time))

    if [[ $age -gt $MESSAGE_TTL ]]; then
      rm -f "$msg_file"
    fi
  done
}

# =============================================================================
# CLI
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-help}" in
    send)
      send_message "$2" "$3" "${4:-cli}"
      echo "Message sent to $2"
      ;;
    receive)
      receive_messages "$2"
      ;;
    peek)
      peek_messages "$2"
      ;;
    wait)
      wait_for_message "$2" "$3" "${4:-60}"
      ;;
    broadcast)
      broadcast_message "$2" "$3" "${4:-cli}"
      echo "Broadcast sent to $2 agents"
      ;;
    request)
      request "$2" "$3" "${4:-30}"
      ;;
    help|*)
      echo "Usage: $0 {send|receive|peek|wait|broadcast|request}"
      echo ""
      echo "Commands:"
      echo "  send <target> <message> [sender]    - Send message to agent"
      echo "  receive <agent_id>                  - Get unread messages"
      echo "  peek <agent_id>                     - View all messages"
      echo "  wait <agent_id> <pattern> [timeout] - Wait for specific message"
      echo "  broadcast <type> <message> [sender] - Send to all agents of type"
      echo "  request <target> <message> [timeout]- Request-response"
      echo ""
      echo "Agent types for broadcast: pm, engineer, all"
      ;;
  esac
fi

# Export functions for sourcing
export -f init_messaging send_message receive_messages peek_messages wait_for_message broadcast_message request respond cleanup_old_messages
