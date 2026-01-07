#!/usr/bin/env bash
# ralph-linear-sync.sh - Sync prd.json features with Linear issues
# Creates, updates, and tracks Linear issues for each feature

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/ralph-config.sh"
source "$SCRIPT_DIR/ralph-linear.sh"

# =============================================================================
# SYNC FUNCTIONS
# =============================================================================

# Initialize Linear issues from prd.json
init_linear() {
  log "Initializing Linear issues from prd.json..."

  if [[ ! -f "$PRD_FILE" ]]; then
    log_error "No prd.json found"
    return 1
  fi

  local project_name
  project_name=$(jq -r '.project // "Ralph Project"' "$PRD_FILE")

  local features
  features=$(jq -c '.features[]' "$PRD_FILE")

  local created=0
  local skipped=0

  while IFS= read -r feature; do
    local id name description linear_id priority

    id=$(echo "$feature" | jq -r '.id')
    name=$(echo "$feature" | jq -r '.name')
    description=$(echo "$feature" | jq -r '.description // ""')
    linear_id=$(echo "$feature" | jq -r '.linear_id // empty')
    priority=$(echo "$feature" | jq -r '.priority // 0')

    # Skip if already has Linear ID
    if [[ -n "$linear_id" ]]; then
      log_debug "Feature $id already has Linear issue: $linear_id"
      skipped=$((skipped + 1))
      continue
    fi

    # Build full description
    local full_desc="**Feature ID:** $id
**Priority:** $priority

$description"

    # Add acceptance criteria if present
    local criteria
    criteria=$(echo "$feature" | jq -r '.acceptance_criteria // [] | .[]' 2>/dev/null || true)
    if [[ -n "$criteria" ]]; then
      full_desc="$full_desc

**Acceptance Criteria:**
$(echo "$criteria" | sed 's/^/- /')"
    fi

    # Add dependencies if present
    local deps
    deps=$(echo "$feature" | jq -r '.depends_on // [] | join(", ")' 2>/dev/null || true)
    if [[ -n "$deps" ]]; then
      full_desc="$full_desc

**Dependencies:** $deps"
    fi

    # Create Linear issue
    log "Creating Linear issue for: $id - $name"
    local result
    result=$(create_issue "[$id] $name" "$full_desc")

    if [[ -n "$result" ]]; then
      local new_linear_id issue_key issue_url
      new_linear_id=$(echo "$result" | cut -f1)
      issue_key=$(echo "$result" | cut -f2)
      issue_url=$(echo "$result" | cut -f3)

      # Update prd.json with Linear ID
      local tmp_file
      tmp_file=$(mktemp)
      jq --arg id "$id" --arg linear_id "$new_linear_id" --arg linear_key "$issue_key" --arg linear_url "$issue_url" '
        (.features[] | select(.id == $id)) += {
          linear_id: $linear_id,
          linear_key: $linear_key,
          linear_url: $linear_url
        }
      ' "$PRD_FILE" > "$tmp_file" && mv "$tmp_file" "$PRD_FILE"

      # Also update state.json if it exists
      if [[ -f "$STATE_FILE" ]]; then
        tmp_file=$(mktemp)
        jq --arg id "$id" --arg linear_id "$new_linear_id" --arg linear_key "$issue_key" --arg linear_url "$issue_url" '
          (.features[] | select(.id == $id)) += {
            linear_id: $linear_id,
            linear_key: $linear_key,
            linear_url: $linear_url
          }
        ' "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
      fi

      log "Created: $issue_key ($issue_url)"
      created=$((created + 1))
    else
      log_error "Failed to create issue for $id"
    fi

  done <<< "$features"

  log "Linear sync complete: $created created, $skipped skipped"
}

# Pull status from Linear to local state
pull_status() {
  log "Pulling status from Linear..."

  if [[ ! -f "$STATE_FILE" ]]; then
    log_error "No state.json found"
    return 1
  fi

  local features
  features=$(jq -c '.features[]' "$STATE_FILE")

  local updated=0

  while IFS= read -r feature; do
    local id linear_id local_status

    id=$(echo "$feature" | jq -r '.id')
    linear_id=$(echo "$feature" | jq -r '.linear_id // empty')
    local_status=$(echo "$feature" | jq -r '.status')

    if [[ -z "$linear_id" ]]; then
      log_debug "Feature $id has no Linear issue"
      continue
    fi

    # Get Linear issue status
    local issue
    issue=$(get_issue "$linear_id" 2>/dev/null || true)

    if [[ -z "$issue" || "$issue" == "null" ]]; then
      log_warn "Could not fetch Linear issue for $id"
      continue
    fi

    local linear_state
    linear_state=$(echo "$issue" | jq -r '.state.name')

    # Map Linear state to local status
    local mapped_status
    case "$linear_state" in
      "Backlog"|"Todo"|"Triage")
        mapped_status="pending"
        ;;
      "In Progress"|"Started")
        mapped_status="in_progress"
        ;;
      "Blocked"|"On Hold")
        mapped_status="blocked"
        ;;
      "In Review"|"Done"|"Completed"|"Canceled")
        mapped_status="completed"
        ;;
      *)
        mapped_status="$local_status"  # Keep existing
        ;;
    esac

    # Update if different
    if [[ "$mapped_status" != "$local_status" ]]; then
      log "Updating $id: $local_status -> $mapped_status (Linear: $linear_state)"

      local tmp_file
      tmp_file=$(mktemp)
      jq --arg id "$id" --arg status "$mapped_status" '
        (.features[] | select(.id == $id)).status = $status
      ' "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"

      updated=$((updated + 1))
    fi

  done <<< "$features"

  log "Pull complete: $updated updated"
}

# Push local status to Linear
push_status() {
  log "Pushing status to Linear..."

  if [[ ! -f "$STATE_FILE" ]]; then
    log_error "No state.json found"
    return 1
  fi

  local features
  features=$(jq -c '.features[]' "$STATE_FILE")

  local updated=0

  while IFS= read -r feature; do
    local id linear_id local_status

    id=$(echo "$feature" | jq -r '.id')
    linear_id=$(echo "$feature" | jq -r '.linear_id // empty')
    local_status=$(echo "$feature" | jq -r '.status')

    if [[ -z "$linear_id" ]]; then
      continue
    fi

    # Map local status to Linear state
    local target_state
    case "$local_status" in
      "pending")
        target_state="${LINEAR_STATE_TODO:-Todo}"
        ;;
      "in_progress")
        target_state="${LINEAR_STATE_IN_PROGRESS:-In Progress}"
        ;;
      "blocked")
        target_state="${LINEAR_STATE_BLOCKED:-Blocked}"
        ;;
      "completed")
        target_state="${LINEAR_STATE_IN_REVIEW:-In Review}"
        ;;
      *)
        continue
        ;;
    esac

    # Get current Linear state
    local issue
    issue=$(get_issue "$linear_id" 2>/dev/null || true)

    if [[ -z "$issue" || "$issue" == "null" ]]; then
      continue
    fi

    local current_state
    current_state=$(echo "$issue" | jq -r '.state.name')

    # Update if different
    if [[ "$current_state" != "$target_state" ]]; then
      log "Updating Linear $id: $current_state -> $target_state"
      update_status "$linear_id" "$target_state" >/dev/null || true
      updated=$((updated + 1))
    fi

  done <<< "$features"

  log "Push complete: $updated updated"
}

# Update a single feature's Linear issue
update_feature() {
  local feature_id="$1"
  local status="$2"
  local comment="${3:-}"

  # Get Linear ID from state
  local linear_id
  linear_id=$(jq -r --arg id "$feature_id" '.features[] | select(.id == $id) | .linear_id // empty' "$STATE_FILE")

  if [[ -z "$linear_id" ]]; then
    log_warn "Feature $feature_id has no Linear issue"
    return 0
  fi

  # Map status to Linear state
  local target_state
  case "$status" in
    "pending")
      target_state="${LINEAR_STATE_TODO:-Todo}"
      ;;
    "in_progress")
      target_state="${LINEAR_STATE_IN_PROGRESS:-In Progress}"
      ;;
    "blocked")
      target_state="${LINEAR_STATE_BLOCKED:-Blocked}"
      ;;
    "completed")
      target_state="${LINEAR_STATE_IN_REVIEW:-In Review}"
      ;;
    *)
      target_state="$status"
      ;;
  esac

  # Update status
  update_status "$linear_id" "$target_state" >/dev/null

  # Add comment if provided
  if [[ -n "$comment" ]]; then
    add_comment "$linear_id" "$comment" >/dev/null
  fi
}

# Get Linear issue ID for a feature
get_linear_id() {
  local feature_id="$1"
  jq -r --arg id "$feature_id" '.features[] | select(.id == $id) | .linear_id // empty' "$STATE_FILE"
}

# =============================================================================
# CLI
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-help}" in
    init)
      init_linear
      ;;
    pull)
      pull_status
      ;;
    push)
      push_status
      ;;
    sync)
      push_status
      pull_status
      ;;
    update)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        echo "Usage: $0 update <feature-id> <status> [comment]" >&2
        exit 1
      fi
      update_feature "$2" "$3" "${4:-}"
      ;;
    help|*)
      echo "Usage: $0 <command>"
      echo ""
      echo "Commands:"
      echo "  init              - Create Linear issues from prd.json"
      echo "  pull              - Pull status from Linear to local"
      echo "  push              - Push local status to Linear"
      echo "  sync              - Push then pull (bidirectional)"
      echo "  update <id> <s>   - Update single feature status"
      ;;
  esac
fi

# Export functions for sourcing
export -f init_linear pull_status push_status update_feature get_linear_id
