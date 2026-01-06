# Hybrid Development Workflow (v4)

> **Philosophy**: "The biggest mistake everyone makes is rushing through context—you need patience to tell AI what it actually needs to know." — Ryan Carson

## The Synergy Model

```
    YOU                          ME (Claude)                    RALPH
     │                              │                             │
     │  "I want to build X"         │                             │
     ├─────────────────────────────►│                             │
     │                              │                             │
     │◄────────────────────────────►│  DESIGN PHASE               │
     │   Clarifying questions,      │  (Interactive)              │
     │   architecture decisions     │                             │
     │                              │                             │
     │  "Looks good, batch ready"   │                             │
     ├─────────────────────────────►│                             │
     │                              │  Creates HANDOFF.md         │
     │  Reviews & approves          │  Creates prd.json           │
     ├─────────────────────────────►│                             │
     │                              │                             │
     │                              ├────────────────────────────►│
     │                              │  BATCH PHASE                │
     │   (You can walk away)        │  PM validates → Engineers   │
     │                              │                             │
     │                              │◄────────────────────────────┤
     │                              │  PRs ready                  │
     │  "I'm back"                  │                             │
     ├─────────────────────────────►│                             │
     │                              │                             │
     │◄────────────────────────────►│  REVIEW PHASE               │
     │   Review PRs together,       │  (Interactive)              │
     │   handle edge cases          │                             │
     │                              │                             │
     │  Merge approved PRs          │                             │
     └──────────────────────────────┴─────────────────────────────┘
```

---

## Architecture Modes

### Flat Mode (Default)
```
Orchestrator → Engineer Agents (parallel)
```
- Simple, fast
- Best for well-defined, independent features
- Run: `./ralph-orchestrator.sh run`

### Hierarchical Mode (--with-pm)
```
Orchestrator → PM Agents → Engineer Agents
```
- PM validates specs before engineers start
- PM reviews code before PR creation
- Best for complex features or teams needing validation gates
- Run: `./ralph-orchestrator.sh --with-pm run`

---

## When to Use Each Mode

### Interactive (You + Claude)
- Understanding requirements
- Resolving ambiguity (**clarifying questions MUST be answered**)
- Making architectural decisions
- Handling edge cases
- Reviewing and refining
- Anything requiring judgment

### Batch (Ralph Agents)
- Implementing well-defined CRUD
- Creating boilerplate
- Writing tests for clear specs
- Applying patterns across files
- Anything mechanical and repetitive

---

## Quick Start

### 1. Start a New Project

```
You: "I want to build a task management API with projects, tasks, and users"

Claude: ## Clarifying Questions (REQUIRED)

        1. Authentication
           1.1. Which auth method? (JWT, sessions, OAuth)
           1.2. Token expiry duration?

        2. Data Model
           2.1. Soft delete or hard delete?
           2.2. Required fields beyond basics?

        [Waits for answers before proceeding]
```

### 2. Approve Batch Scope

Review `HANDOFF.md`:
- Understand what's going to batch
- Confirm what stays interactive
- Sign off on API contracts
- Verify clarifying questions resolved

### 3. Start Batch

```bash
# Flat mode (engineers only)
./ralph-scripts/ralph-orchestrator.sh run

# Hierarchical mode (PM validation + engineers)
./ralph-scripts/ralph-orchestrator.sh --with-pm run

# With more agents
./ralph-scripts/ralph-orchestrator.sh --agents 5 run

# Hierarchical with 2 PMs
./ralph-scripts/ralph-orchestrator.sh --with-pm --pms 2 run
```

### 4. Check Progress

```bash
./ralph-scripts/ralph-status.sh
```

### 5. Review When Ready

Come back to find:
- PRs ready for review
- Blocked items needing your input
- Cost and duration summary

---

## v4 Features

### PM Layer (`ralph-pm.sh`)

Project Managers provide an additional validation layer:

| Responsibility | What It Does |
|----------------|--------------|
| Spec Validation | Checks for ambiguity before engineering |
| Work Breakdown | Splits large features into subtasks |
| Code Review | Reviews implementation before PR |
| Coordination | Manages cross-feature dependencies |

### Inter-Agent Messaging (`ralph-message.sh`)

Agents can communicate with each other:

```bash
# Send message
./ralph-message.sh send agent-1 "REVIEW:feature-123:branch-name"

# Receive messages
./ralph-message.sh receive agent-1

# Broadcast to all engineers
./ralph-message.sh broadcast engineer "PAUSE: integration test starting"

# Request-response pattern
./ralph-message.sh request pm-1 "VALIDATE:feature-123"
```

### Self-Scheduling (`ralph-schedule.sh`)

Agents can schedule their own wake-ups:

```bash
# Schedule a wake-up
./ralph-schedule.sh schedule agent-1 300 "Check PR status"

# Check for due wake-ups
./ralph-schedule.sh check agent-1

# List pending schedules
./ralph-schedule.sh list agent-1

# Run scheduler daemon (started by orchestrator)
./ralph-schedule.sh daemon
```

---

## File Structure

```
your-project/
├── ARCHITECTURE.md          # Design decisions (from interactive phase)
├── HANDOFF.md               # Batch approval document
├── INTERACTIVE.md           # Features kept for human judgment
├── prd.json                 # Batch feature specs (static)
├── project.json             # Tech stack config
├── progress/
│   ├── state.json           # Batch progress (dynamic, git-ignored)
│   ├── cost.log             # API cost tracking
│   ├── messages/            # Inter-agent message queues
│   │   ├── agent-1/         # Inbox for agent-1
│   │   └── pm-1/            # Inbox for pm-1
│   └── schedule/            # Scheduled wake-ups
└── ralph-scripts/           # Orchestration scripts
    ├── ralph-orchestrator.sh
    ├── ralph-agent.sh
    ├── ralph-pm.sh          # PM agent (hierarchical mode)
    ├── ralph-message.sh     # Inter-agent messaging
    ├── ralph-schedule.sh    # Self-scheduling
    ├── ralph-status.sh      # Progress checking
    ├── ralph-claim.sh       # Atomic feature claiming
    ├── ralph-lock.sh        # Portable locking
    ├── ralph-heartbeat.sh   # Stale claim recovery
    └── PROMPT.md            # Agent instructions
```

---

## Commands Reference

| When | Command | What It Does |
|------|---------|--------------|
| Design | `/hybrid-dev` | Start hybrid workflow |
| Design | `/prd-generator` | Create batch specs (with clarifying questions) |
| Pre-batch | Review HANDOFF.md | Approve scope |
| Batch | `./ralph-orchestrator.sh run` | Start flat mode |
| Batch | `./ralph-orchestrator.sh --with-pm run` | Start hierarchical mode |
| Batch | `./ralph-status.sh` | Check progress |
| Batch | `./ralph-message.sh peek <agent>` | View agent messages |
| Batch | `./ralph-schedule.sh list <agent>` | View scheduled wake-ups |
| Batch | Ctrl+C | Stop early |
| Review | Come back to Claude | Summarize & review |

---

## The Carson Rules

### 1. Clarifying Questions (REQUIRED)
Before any batch work, ambiguities must be resolved. Use dot notation:

```markdown
1. Authentication
   1.1. Which auth method?
   1.2. Token expiry?
2. Data Model
   2.1. Required fields?
```

**Do not proceed until questions are answered.**

### 2. One Subtask at a Time
- Complete one subtask fully before moving to next
- Mark completion immediately
- Pause after each for potential course correction
- Commit at stable points

### 3. Explicit API Contracts
For each endpoint, specify:
- Request shape with types and validation rules
- Response shape with exact structure
- Error codes and messages

### 4. Batch vs Interactive Classification
Every feature must be marked:

| Feature | Mode | Reason |
|---------|------|--------|
| User model | Batch | Clear schema, mechanical |
| OAuth setup | Interactive | Credential decisions needed |

---

## The Handoff Contract

Before batch starts, we create `HANDOFF.md` together:

1. **What I Understand** - My summary of requirements
2. **Clarifying Questions Resolved** - Q&A from discussion
3. **Design Decisions** - What we agreed on
4. **Batch Scope** - Features for autonomous work (batch_ready: true)
5. **Interactive Scope** - Features staying interactive
6. **API Contracts** - Summary of endpoints
7. **Success Criteria** - How we know it worked

You review and approve. **Then** batch runs.

---

## Golden Rules

1. **Never batch ambiguity** - If it's unclear, keep it interactive
2. **Clarifying questions first** - No batch until resolved
3. **Explicit phase transitions** - You say "batch ready", not me
4. **One subtask at a time** - Complete fully before moving on
5. **Context flows forward** - Design discussions inform batch prompts
6. **Review everything** - Batch creates PRs, humans merge them
7. **Default interactive** - When unsure, stay conversational

---

## Why This Works

| Phase | Optimizes For |
|-------|---------------|
| Design | Quality of decisions |
| Batch | Throughput of implementation |
| Review | Quality of output |

Human judgment at the edges. Machine throughput in the middle.

---

## FAQ

**Q: What if batch gets stuck?**
A: Features marked "blocked" wait for you. Come back, discuss, unblock.

**Q: What if I realize batch scope was wrong?**
A: Stop batch (Ctrl+C), discuss, adjust PRD, restart.

**Q: Can I check in during batch?**
A: Yes! `./ralph-status.sh` shows progress without interrupting.

**Q: What if I want to change something mid-batch?**
A: Let current features finish, then modify PRD for remaining work.

**Q: How do I know when to use batch vs interactive?**
A: If you can write a clear acceptance test for it → batch. If you'd say "it depends" → interactive.

**Q: When should I use --with-pm mode?**
A: Use hierarchical mode when:
- Features are complex or touch multiple systems
- You want an additional validation layer
- Specs might need refinement during implementation
- Cross-feature coordination is important

**Q: How do agents communicate?**
A: Through `ralph-message.sh`. Each agent has an inbox at `progress/messages/<agent-id>/`. Messages are JSON files with sender, content, and read status.

**Q: What's self-scheduling for?**
A: Agents can schedule their own check-ins (e.g., "check PR status in 5 minutes"). Useful for async operations and 24/7 operation patterns.
