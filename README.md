# Super Claude Dev

An autonomous development system that enables Claude to implement features in parallel, with async human collaboration via Linear (or Slack).

## Overview

Super Claude Dev turns a product idea into working code with minimal human intervention:

1. **You describe** what you want to build
2. **Claude analyzes** and creates a feature breakdown (PRD)
3. **Multiple agents** implement features in parallel
4. **Linear/Slack notifies** you when decisions are needed
5. **You respond** from your phone - Claude continues
6. **PRs are created** automatically for review

Human role: Make judgment calls, approve PRs. That's it.

## Current Status

See [STATUS.md](STATUS.md) for the latest system state and next steps.

## Quick Start

### Prerequisites

```bash
# Required
brew install jq
npm install -g @anthropic-ai/claude-code

# Verify GitHub CLI
gh auth status
```

### Setup Linear (Recommended)

```bash
# Add to ~/.zshrc
export LINEAR_API_KEY="lin_api_your_key_here"
export LINEAR_TEAM_ID="your-team-uuid-here"
```

See [LINEAR-SETUP.md](ralph-scripts/LINEAR-SETUP.md) for detailed instructions.

### Setup Slack (Alternative)

```bash
# Simple mode (notifications only)
export SLACK_WEBHOOK_URL="<your-webhook-url>"

# Full mode (bidirectional)
export SLACK_BOT_TOKEN="xoxb-your-token"
export SLACK_CHANNEL="#ralph-updates"
```

See [SLACK-SETUP.md](ralph-scripts/SLACK-SETUP.md) for detailed instructions.

### Run on a New Project

```bash
# 1. Create/navigate to project
mkdir my-project && cd my-project

# 2. Analyze or scaffold
claude "/project-analyzer"

# 3. Generate feature specs
claude "/prd-generator"

# 4. Run autonomous development
./ralph-scripts/ralph-orchestrator.sh run
```

### Run on This Project

```bash
cd /path/to/super-claude-dev
./ralph-scripts/ralph-orchestrator.sh run
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ORCHESTRATOR                              │
│  Spawns agents, monitors health, coordinates completion         │
└─────────────────┬───────────────────────────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
┌────────┐   ┌────────┐   ┌────────┐
│ Agent 1│   │ Agent 2│   │ Agent 3│    ← Parallel feature work
└───┬────┘   └───┬────┘   └───┬────┘
    │            │            │
    ▼            ▼            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CLAIM SYSTEM                                │
│  Atomic locking, heartbeats, stale claim recovery               │
└─────────────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                 LINEAR / SLACK INTEGRATION                       │
│  Issue updates → Human ← Comments/Responses                      │
└─────────────────────────────────────────────────────────────────┘
```

## Scripts Reference

### Core

| Script | Purpose |
|--------|---------|
| `ralph-orchestrator.sh` | Spawns and manages parallel agents |
| `ralph-agent.sh` | Single agent worker loop |
| `ralph-config.sh` | Shared configuration |
| `ralph-claim.sh` | Atomic feature claiming |
| `ralph-lock.sh` | Portable file locking |
| `ralph-heartbeat.sh` | Stale claim recovery |

### Linear Integration

| Script | Purpose |
|--------|---------|
| `ralph-linear.sh` | Linear GraphQL API wrapper |
| `ralph-linear-sync.sh` | Sync prd.json ↔ Linear issues |

### Slack Integration

| Script | Purpose |
|--------|---------|
| `ralph-slack.sh` | Send/receive Slack messages |
| `ralph-notify.sh` | Rich Block Kit notifications |
| `ralph-decisions.sh` | Async decision queue |
| `ralph-slack-listener.sh` | Listen for Slack responses |
| `ralph-status.sh` | Status reporting |

### Integration & Merge

| Script | Purpose |
|--------|---------|
| `ralph-integration.sh` | Cross-feature integration testing |
| `ralph-merge-calculator.sh` | Dependency-aware merge ordering |

### PM Layer

| Script | Purpose |
|--------|---------|
| `ralph-pm.sh` | Project management coordination |
| `ralph-message.sh` | Inter-agent messaging |
| `ralph-schedule.sh` | Work scheduling |

## Skills

Located in `~/.claude/skills/`:

| Skill | Purpose |
|-------|---------|
| `project-analyzer` | Scaffold new or analyze existing projects |
| `prd-generator` | Generate feature specs from ideas |
| `feature-runner` | TDD/direct/docs implementation workflows |
| `ci-responder` | Auto-fix CI failures |
| `integration-tester` | Cross-feature integration tests |
| `hybrid-dev` | Interactive + autonomous workflow |

## Slack Commands

When connected to Slack, respond with:

| Command | Action |
|---------|--------|
| `status` | Show progress |
| `pause` | Pause all agents |
| `resume` | Resume agents |
| `abort` | Stop Ralph |
| `decisions` | Show pending decisions |
| `1` / `2` / `3` | Quick answer to decision |
| `dec-123456 Answer` | Answer specific decision |

## Configuration

### Environment Variables

```bash
# Slack
SLACK_WEBHOOK_URL     # Webhook mode (outbound only)
SLACK_BOT_TOKEN       # Bot mode (bidirectional)
SLACK_CHANNEL         # Channel name (default: #ralph-updates)

# Limits
MAX_PARALLEL_AGENTS=3        # Concurrent agents
MAX_ITERATIONS_PER_FEATURE=5 # Retries before blocking
MAX_DAILY_COST_USD=50        # Cost ceiling
```

### Files

| File | Purpose |
|------|---------|
| `prd.json` | Feature specifications |
| `project.json` | Project metadata |
| `progress/` | Runtime state and logs |

## GitHub Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `claude-ci.yml` | Push/PR | Run tests, lint, type check |
| `claude-fix.yml` | CI failure | Auto-fix and retry |

## How It Works

### 1. Feature Claiming

Agents atomically claim features using portable `mkdir` locking:

```bash
# Only one agent can claim a feature
./ralph-scripts/ralph-claim.sh claim todo-001 agent-1
```

### 2. Decision Flow

When an agent needs human input:

```
Agent → DECISION_NEEDED promise → Slack notification
                                        ↓
Human responds via Slack ────────────────┘
                                        ↓
Decision file updated ← Agent unblocks and continues
```

### 3. Completion

Features complete when:
- Code implemented
- Tests pass
- PR created
- Agent outputs `<promise>FEATURE_COMPLETE:id</promise>`

## Development

### Adding a New Script

1. Create in `ralph-scripts/`
2. Source `ralph-config.sh` for shared settings
3. Make executable: `chmod +x ralph-scripts/your-script.sh`
4. Export functions if sourced by others

### Testing

```bash
# Run project tests
npm test

# Test Ralph components
./ralph-scripts/ralph-status.sh summary
./ralph-scripts/ralph-decisions.sh pending
./ralph-scripts/ralph-slack.sh test
```

## License

MIT

## Credits

Built with [Claude Code](https://claude.com/claude-code) using the [Ralph Wiggum technique](https://ghuntley.com/ralph/).
