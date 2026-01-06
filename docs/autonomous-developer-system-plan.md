# Autonomous Software Developer System (v3 - Complete End-to-End)

## Overview

Transform Claude into an autonomous software developer that takes an **idea** and produces a **finished product** with minimal human intervention.

**Human-only actions:**
1. Approve PR merges
2. Provide secrets when blocked
3. Review skill suggestions

## What's New in v3

| v2 Gap | v3 Solution |
|--------|-------------|
| No project bootstrap | `project-analyzer` skill scaffolds new or analyzes existing |
| No CI failure handling | `claude-fix.yml` auto-triggers fixes |
| No merge orchestration | `ralph-merge-calculator.sh` with topological sort |
| No integration testing | `ralph-integration.sh` phase |
| `flock` not on macOS | Portable `mkdir`-based locking |
| No stale claim recovery | `ralph-heartbeat.sh` daemon |
| No cost monitoring | Daily budget limits with tracking |
| No API contract definition | PRD schema includes contracts |
| No dependency handling | `packages_needed` in features |

---

## Complete Workflow

```
USER: "Build me an auth system"
           │
           ▼
┌──────────────────────────────────────┐
│ PHASE 1: PROJECT BOOTSTRAP           │
│ • New project → scaffold (tech stack)│
│ • Existing → analyze (patterns, deps)│
│ • Output: project.json               │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ PHASE 2: PRD GENERATION + VALIDATION │
│ • Decompose into 30-min features     │
│ • Define API contracts (OpenAPI-ish) │
│ • Validate: no circular deps         │
│ • Validate: realistic estimates      │
│ • Create Linear issues + prd.json    │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ PHASE 3: PARALLEL FEATURE EXECUTION  │
│ ┌─────────┬─────────┬─────────┐     │
│ │ Agent 1 │ Agent 2 │ Agent 3 │     │
│ └────┬────┴────┬────┴────┬────┘     │
│      │         │         │          │
│   Claim → Implement → PR → Slack    │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ PHASE 4: CI PIPELINE + RESPONSE      │
│ • GitHub Actions: test + lint + cov  │
│ • Claude reviews PR                  │
│ • IF FAIL: CI Agent pushes fix       │
│ • Loop until green (max 3 attempts)  │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ PHASE 5: INTEGRATION TESTING         │
│ • All PRs green individually         │
│ • Run cross-feature integration tests│
│ • E2E smoke tests on combined code   │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ PHASE 6: MERGE ORCHESTRATION         │
│ • Calculate safe merge order (deps)  │
│ • Rebase stale branches              │
│ • Present order to human             │
│ • Human approves, system merges      │
└──────────────────┬───────────────────┘
                   ▼
            FINISHED PRODUCT
```

---

## Prerequisites

```bash
# Check required tools
which jq gh git claude

# macOS install if needed
brew install jq gh

# Verify gh authentication
gh auth status
```

**No external database required** - everything is portable JSON + file locks.

---

## Files Created

All scripts are in `ralph-scripts/`:

| File | Purpose |
|------|---------|
| `ralph-config.sh` | Configuration (agents, costs, paths) |
| `ralph-lock.sh` | Portable mkdir-based locking (macOS compatible) |
| `ralph-claim.sh` | Atomic feature claiming |
| `ralph-heartbeat.sh` | Stale claim recovery daemon |
| `ralph-agent.sh` | Single agent worker |
| `ralph-orchestrator.sh` | Spawns 3 parallel agents |
| `ralph-merge-calculator.sh` | Topological sort for merge order |
| `ralph-integration.sh` | Integration testing phase |
| `PROMPT.md` | Agent prompt template |

Skills in `~/.claude/skills/`:

| Skill | Purpose |
|-------|---------|
| `project-analyzer` | Bootstrap new or analyze existing projects |
| `prd-generator` | Decompose features with validation |
| `feature-runner` | Execute TDD/direct/docs workflows |

GitHub workflows in `.github/workflows/`:

| File | Purpose |
|------|---------|
| `claude-ci.yml` | Test, lint, Claude review |
| `claude-fix.yml` | Auto-fix CI failures |

---

## prd.json Schema (v3)

```json
{
  "project": "User Authentication System",
  "description": "Complete auth with login, registration, password reset",
  "default_branch": "main",
  "api_contracts": {
    "POST /api/auth/login": {
      "request": {"email": "string", "password": "string"},
      "response": {"token": "string", "expiresIn": "number"},
      "errors": [401, 429]
    },
    "POST /api/auth/register": {
      "request": {"email": "string", "password": "string", "name": "string"},
      "response": {"user": {"id": "string"}, "token": "string"},
      "errors": [400, 409]
    }
  },
  "features": [
    {
      "id": "auth-001",
      "name": "User login endpoint",
      "description": "POST /api/auth/login with JWT",
      "priority": 1,
      "linear_id": "ABC-123",
      "workflow_type": "tdd",
      "branch": "feature/auth-001-login",
      "status": "pending",
      "depends_on": [],
      "api_endpoints": ["POST /api/auth/login"],
      "packages_needed": ["jsonwebtoken", "bcrypt"],
      "env_vars_needed": ["JWT_SECRET"],
      "acceptance_criteria": [
        "Accepts email and password",
        "Returns JWT on success",
        "Returns 401 for invalid credentials",
        "Rate limits to 5/minute"
      ],
      "claimed_by": null,
      "claimed_at": null,
      "completed_at": null,
      "pr_url": null,
      "ci_status": null,
      "ci_attempts": 0
    }
  ],
  "integration_tests": [
    {
      "name": "Full auth flow",
      "description": "Register → Login → Token refresh",
      "features": ["auth-001", "auth-002", "auth-003"],
      "status": "pending"
    }
  ]
}
```

### Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Not started, available to claim |
| `in_progress` | Claimed by an agent |
| `completed` | Done, PR created |
| `blocked` | Needs human intervention |

### Workflow Types

| Type | Use Case | Process |
|------|----------|---------|
| `tdd` | Business logic, APIs | RED → GREEN → REFACTOR |
| `direct` | Config, infra, UI | Implement → Verify → Commit |
| `docs` | Documentation | Write → Review → Commit |

---

## Key Technical Features

### 1. Portable Locking (macOS Compatible)

Replaces `flock` with atomic `mkdir`:

```bash
# Acquire lock
acquire_lock() {
  local lock_dir="/tmp/ralph-lock-$1"
  while ! mkdir "$lock_dir" 2>/dev/null; do
    sleep 1
  done
  echo "$lock_dir"
}

# Release lock
release_lock() {
  rmdir "$1"
}
```

### 2. Heartbeat & Stale Claim Recovery

Daemon releases claims after 10 minutes of inactivity:

```bash
# ralph-heartbeat.sh daemon
while true; do
  sleep 60
  # Find claims older than threshold with no progress
  # Release them back to pending
done
```

### 3. CI Auto-Fix (Max 3 Attempts)

`claude-fix.yml` triggers on CI failure:
1. Fetches failure logs
2. Claude analyzes and fixes
3. Pushes to same branch
4. Increments `ci_attempts`
5. After 3 failures → marks as `blocked`

### 4. Topological Merge Order

`ralph-merge-calculator.sh` uses Kahn's algorithm:
1. Build dependency graph from `depends_on`
2. Sort features so dependencies merge first
3. Generate merge plan document
4. Human approves, merges in order

### 5. Integration Testing Phase

After all PRs pass individually:
1. Create integration branch from main
2. Merge all features in dependency order
3. Run integration tests
4. Run E2E smoke tests
5. Document any cross-feature issues

### 6. Cost Monitoring

Daily budget with per-call tracking:
```bash
MAX_DAILY_COST_USD=50

log_cost() {
  # Calculate cost per call
  # Append to progress/cost.log
  # Check if over budget → pause agents
}
```

---

## Quick Start

### Step 1: Setup Prerequisites

```bash
# Clone scripts
cp -r ralph-scripts/ /path/to/your/project/

# Make executable
chmod +x ralph-scripts/*.sh

# Set environment
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
```

### Step 2: Initialize Project

```bash
# For new project
claude --prompt "Use the project-analyzer skill to scaffold a Node.js Express API"

# For existing project
claude --prompt "Use the project-analyzer skill to analyze this codebase"
```

This creates `project.json` with tech stack info.

### Step 3: Generate PRD

```bash
claude --prompt "Use the prd-generator skill to create a PRD for: Build a user authentication system with login, registration, and password reset"
```

This creates `prd.json` with features.

### Step 4: Run Orchestrator

```bash
cd /path/to/your/project/
./ralph-scripts/ralph-orchestrator.sh run
```

This:
- Spawns 3 parallel agents
- Starts heartbeat daemon
- Agents claim features, implement, create PRs
- Notifies Slack on progress

### Step 5: Monitor Progress

```bash
# Check status
./ralph-scripts/ralph-orchestrator.sh status

# View logs
cat progress/*.log

# Check costs
cat progress/cost.log
```

### Step 6: Integration & Merge

After all features complete:

```bash
# Run integration tests
./ralph-scripts/ralph-integration.sh run

# Generate merge plan
./ralph-scripts/ralph-merge-calculator.sh plan

# Review and merge (human)
cat progress/merge-plan.md
```

---

## Configuration

Edit `ralph-config.sh`:

```bash
# Agents
NUM_AGENTS=3
MAX_ITERATIONS_PER_FEATURE=20
MAX_CI_ATTEMPTS=3

# Cost limits
MAX_DAILY_COST_USD=50

# Timeouts
STALE_CLAIM_THRESHOLD=600  # 10 minutes
HEARTBEAT_INTERVAL=60

# Slack
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
```

---

## Troubleshooting

### Agent won't claim features
```bash
# Check claimable features
./ralph-scripts/ralph-claim.sh list

# Check for stale claims
./ralph-scripts/ralph-heartbeat.sh check
```

### CI keeps failing
```bash
# Check attempt count
jq '.features[] | select(.ci_attempts >= 3)' prd.json

# Manual intervention needed for blocked features
```

### Merge conflicts
```bash
# Validate merge order
./ralph-scripts/ralph-merge-calculator.sh validate

# Rebase stale branch
git checkout feature/xxx && git rebase origin/main
```

### Over budget
```bash
# Check daily cost
cat progress/cost.log | awk -F',' '{sum+=$6} END {print sum}'

# Agents auto-pause at limit
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Infinite CI fix loop | Max 3 attempts, then blocked |
| Merge conflicts | Rebase before merge, alert on conflict |
| Integration failures | Create fix tasks, re-run implementation |
| Cost overrun | Hard daily limit, pause agents |
| Agent crash | Heartbeat releases stale claims |
| Linear API down | Local cache in `.claude/cache/` |

---

## Success Criteria

1. ✅ User provides idea in plain English
2. ✅ System scaffolds or analyzes project
3. ✅ PRD generated with validated dependencies
4. ✅ 3 agents implement features in parallel
5. ✅ CI failures auto-fixed
6. ✅ Integration tests pass
7. ✅ Merge order calculated
8. ✅ Human only approves merges
9. ✅ Finished product ready

---

## References

- [Ralph Wiggum Technique](https://ghuntley.com/ralph/)
- [Linear MCP Documentation](https://linear.app/docs/mcp)
- [Claude GitHub Action](https://github.com/anthropics/claude-code-action)
- [Claude Code Skills](https://code.claude.com/docs/en/skills)
- [Ralph Orchestrator](https://github.com/mikeyobrien/ralph-orchestrator)
