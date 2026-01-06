#!/usr/bin/env bash
# ralph-pm.sh - Project Manager agent
# Validates specs, assigns work to engineers, reviews output
#
# HIERARCHY:
#   Orchestrator → PM → Engineers
#
# PM responsibilities:
#   1. Validate feature specs before engineering starts
#   2. Break down complex features into engineer-sized chunks
#   3. Review engineer output before PR creation
#   4. Coordinate cross-feature dependencies

set -euo pipefail

source "$(dirname "$0")/ralph-config.sh"
source "$(dirname "$0")/ralph-claim.sh"
source "$(dirname "$0")/ralph-message.sh"

# =============================================================================
# PM CONFIGURATION
# =============================================================================

PM_ID="${1:-pm-1}"
PM_LOG="${PROGRESS_DIR}/pm-${PM_ID}.log"
VALIDATION_CACHE="${CACHE_DIR}/validations"

mkdir -p "$VALIDATION_CACHE"

# =============================================================================
# LOGGING
# =============================================================================

pm_log() {
  local message="$1"
  local timestamp=$(date -Iseconds)
  echo "[$timestamp] [PM:$PM_ID] $message" | tee -a "$PM_LOG" >&2
}

# =============================================================================
# SPEC VALIDATION
# =============================================================================

# Validate a feature spec before it goes to engineers
# Returns: 0 if valid, 1 if needs clarification
validate_feature_spec() {
  local feature_id="$1"

  pm_log "Validating spec for $feature_id"

  # Get feature from PRD
  local feature_spec
  feature_spec=$(jq --arg id "$feature_id" '.features[] | select(.id == $id)' "$PRD_FILE")

  if [[ -z "$feature_spec" || "$feature_spec" == "null" ]]; then
    pm_log "ERROR: Feature $feature_id not found in PRD"
    return 1
  fi

  # Check required fields
  local missing_fields=()

  # Must have name
  local name=$(echo "$feature_spec" | jq -r '.name // empty')
  [[ -z "$name" ]] && missing_fields+=("name")

  # Must have acceptance criteria
  local criteria=$(echo "$feature_spec" | jq -r '.acceptance_criteria // empty')
  [[ -z "$criteria" || "$criteria" == "[]" ]] && missing_fields+=("acceptance_criteria")

  # Should have priority
  local priority=$(echo "$feature_spec" | jq -r '.priority // empty')
  [[ -z "$priority" ]] && missing_fields+=("priority")

  if [[ ${#missing_fields[@]} -gt 0 ]]; then
    pm_log "INVALID: Missing fields: ${missing_fields[*]}"

    # Record validation failure
    echo "{\"feature_id\": \"$feature_id\", \"status\": \"invalid\", \"missing\": [\"${missing_fields[*]}\"], \"timestamp\": \"$(date -Iseconds)\"}" \
      > "$VALIDATION_CACHE/${feature_id}.json"

    return 1
  fi

  # Use Claude to do deeper validation
  local validation_prompt="You are a Project Manager validating a feature spec.

Feature Spec:
$feature_spec

Validate this spec for an engineer to implement. Check:
1. Are requirements unambiguous? (No 'it depends' situations)
2. Are acceptance criteria testable?
3. Are dependencies clearly stated?
4. Is scope well-defined? (Not too large for one PR)

If valid, output exactly: VALID
If issues found, output: INVALID: <specific issues>

Be strict. Engineers need clear specs."

  local validation_result
  validation_result=$(echo "$validation_prompt" | claude --print 2>/dev/null || echo "INVALID: Claude validation failed")

  if [[ "$validation_result" == *"VALID"* && "$validation_result" != *"INVALID"* ]]; then
    pm_log "VALID: $feature_id passed validation"
    echo "{\"feature_id\": \"$feature_id\", \"status\": \"valid\", \"timestamp\": \"$(date -Iseconds)\"}" \
      > "$VALIDATION_CACHE/${feature_id}.json"
    return 0
  else
    pm_log "INVALID: $validation_result"
    echo "{\"feature_id\": \"$feature_id\", \"status\": \"invalid\", \"reason\": \"$validation_result\", \"timestamp\": \"$(date -Iseconds)\"}" \
      > "$VALIDATION_CACHE/${feature_id}.json"
    return 1
  fi
}

# =============================================================================
# WORK BREAKDOWN
# =============================================================================

# Break down a large feature into engineer-sized subtasks
breakdown_feature() {
  local feature_id="$1"

  pm_log "Breaking down feature $feature_id"

  local feature_spec
  feature_spec=$(jq --arg id "$feature_id" '.features[] | select(.id == $id)' "$PRD_FILE")

  local breakdown_prompt="You are a Project Manager breaking down a feature for engineers.

Feature Spec:
$feature_spec

Break this into subtasks that:
1. Each subtask is completable in one focused session
2. Each subtask has clear start and end state
3. Subtasks are ordered by dependency
4. Use dot notation (e.g., 1.1, 1.2, 2.1) for hierarchy

Output as JSON array:
[
  {\"id\": \"$feature_id.1\", \"task\": \"description\", \"depends_on\": []},
  {\"id\": \"$feature_id.2\", \"task\": \"description\", \"depends_on\": [\"$feature_id.1\"]}
]

If feature is already small enough, output:
[{\"id\": \"$feature_id\", \"task\": \"implement as-is\", \"depends_on\": []}]"

  local breakdown
  breakdown=$(echo "$breakdown_prompt" | claude --print 2>/dev/null)

  # Validate JSON
  if echo "$breakdown" | jq -e '.' > /dev/null 2>&1; then
    echo "$breakdown"
    pm_log "Breakdown complete: $(echo "$breakdown" | jq length) subtasks"
  else
    pm_log "ERROR: Invalid breakdown JSON, returning original"
    echo "[{\"id\": \"$feature_id\", \"task\": \"implement as-is\", \"depends_on\": []}]"
  fi
}

# =============================================================================
# ENGINEER COORDINATION
# =============================================================================

# Assign a validated feature to an available engineer
assign_to_engineer() {
  local feature_id="$1"
  local engineer_id="$2"

  pm_log "Assigning $feature_id to $engineer_id"

  # Send message to engineer
  send_message "$engineer_id" "ASSIGN:$feature_id"

  # Update state
  local lock_dir
  lock_dir=$(acquire_lock "state-pm" 10)

  if [[ "$lock_dir" == "TIMEOUT" ]]; then
    pm_log "ERROR: Could not acquire lock for assignment"
    return 1
  fi

  jq --arg id "$feature_id" \
     --arg eng "$engineer_id" \
     --arg pm "$PM_ID" '\
    (.features[] | select(.id == $id)) |= . + {
      assigned_by: $pm,
      assigned_to: $eng,
      assigned_at: (now | todate)
    }
  ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

  release_lock "$lock_dir"

  pm_log "Assignment complete"
  return 0
}

# Review engineer's completed work before PR
review_engineer_work() {
  local feature_id="$1"
  local branch="$2"

  pm_log "Reviewing work on $feature_id (branch: $branch)"

  # Get the diff
  local diff
  diff=$(git diff "origin/$DEFAULT_BRANCH..origin/$branch" 2>/dev/null || echo "")

  if [[ -z "$diff" ]]; then
    pm_log "ERROR: No diff found for branch $branch"
    return 1
  fi

  # Get feature spec
  local feature_spec
  feature_spec=$(jq --arg id "$feature_id" '.features[] | select(.id == $id)' "$PRD_FILE")

  local review_prompt="You are a Project Manager reviewing an engineer's implementation.

Feature Spec:
$feature_spec

Implementation Diff:
$diff

Review for:
1. Does implementation match the spec?
2. Are acceptance criteria met?
3. Any obvious bugs or issues?
4. Is code quality acceptable?

Output exactly one of:
APPROVED - Ready for PR
CHANGES_NEEDED: <specific feedback>
BLOCKED: <reason requiring human intervention>"

  local review_result
  review_result=$(echo "$review_prompt" | claude --print 2>/dev/null || echo "BLOCKED: Review failed")

  pm_log "Review result: $review_result"

  if [[ "$review_result" == *"APPROVED"* ]]; then
    return 0
  elif [[ "$review_result" == *"CHANGES_NEEDED"* ]]; then
    # Send feedback to engineer
    local feedback="${review_result#*CHANGES_NEEDED: }"
    send_message "engineer-$feature_id" "FEEDBACK:$feedback"
    return 2
  else
    # Blocked - needs human
    local reason="${review_result#*BLOCKED: }"
    block_feature "$feature_id" "PM review: $reason"
    return 1
  fi
}

# =============================================================================
# PM MAIN LOOP
# =============================================================================

run_pm() {
  pm_log "=== Project Manager $PM_ID starting ==="

  while true; do
    # Check for messages
    local messages
    messages=$(receive_messages "$PM_ID")

    for msg in $messages; do
      case "$msg" in
        VALIDATE:*)
          local feature_id="${msg#VALIDATE:}"
          validate_feature_spec "$feature_id"
          ;;
        REVIEW:*)
          local params="${msg#REVIEW:}"
          local feature_id="${params%%:*}"
          local branch="${params#*:}"
          review_engineer_work "$feature_id" "$branch"
          ;;
        SHUTDOWN)
          pm_log "Received shutdown signal"
          exit 0
          ;;
      esac
    done

    # Check for pending features needing validation
    if [[ -f "$STATE_FILE" ]]; then
      local pending_features
      pending_features=$(jq -r '.features[] | select(.status == "pending") | select(.validated != true) | .id' "$STATE_FILE" 2>/dev/null || echo "")

      for feature_id in $pending_features; do
        if validate_feature_spec "$feature_id"; then
          # Mark as validated in state
          local lock_dir
          lock_dir=$(acquire_lock "state-pm" 10)
          if [[ "$lock_dir" != "TIMEOUT" ]]; then
            jq --arg id "$feature_id" '(.features[] | select(.id == $id)) |= . + {validated: true}' \
              "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
            release_lock "$lock_dir"
          fi
        fi
      done
    fi

    # Check for completed features needing review
    local in_review
    in_review=$(jq -r '.features[] | select(.status == "in_review") | .id' "$STATE_FILE" 2>/dev/null || echo "")

    for feature_id in $in_review; do
      local branch
      branch=$(jq -r --arg id "$feature_id" '.features[] | select(.id == $id) | .branch' "$STATE_FILE")
      review_engineer_work "$feature_id" "$branch"
    done

    sleep 30
  done
}

# =============================================================================
# CLI
# =============================================================================

case "${2:-run}" in
  run)
    run_pm
    ;;
  validate)
    validate_feature_spec "$3"
    ;;
  breakdown)
    breakdown_feature "$3"
    ;;
  review)
    review_engineer_work "$3" "$4"
    ;;
  help|*)
    echo "Usage: $0 <pm-id> {run|validate|breakdown|review}"
    echo ""
    echo "Commands:"
    echo "  run                     - Start PM daemon"
    echo "  validate <feature_id>   - Validate a feature spec"
    echo "  breakdown <feature_id>  - Break down into subtasks"
    echo "  review <feature_id> <branch> - Review engineer work"
    ;;
esac
