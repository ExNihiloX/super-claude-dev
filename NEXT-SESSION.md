# Next Session Quick Start

**Last Session:** 2026-01-07
**Focus:** Linear integration testing (completed)

---

## TL;DR - What To Do Next

```bash
cd /Users/maurice/Documents/super-claude-dev

# 1. Ensure Linear credentials are loaded
source ~/.zshrc
./ralph-scripts/ralph-linear.sh test  # Should say "Connected as: Maurice Gorleku"

# 2. Push to GitHub (first time only)
gh repo create super-claude-dev --public --source=. --push

# 3. Run the orchestrator for real
./ralph-scripts/ralph-orchestrator.sh run

# 4. Watch and fix what breaks
```

---

## What Was Accomplished Last Session

1. **Linear Integration Working**
   - API connection verified
   - Team: AURA (`8acb3d44-3310-4676-b43b-835f4babedd7`)
   - 6 Linear issues created (AURA-75 through AURA-80)
   - Fixed JSON escaping bugs in `ralph-linear.sh`

2. **prd.json Updated**
   - All features have `linear_key` and `linear_url`
   - Ready for orchestrator to sync status

3. **Documentation Updated**
   - README.md - Added Linear section
   - STATUS.md - Full system state
   - LINEAR-SETUP.md - Tested configuration

---

## What Has NEVER Been Done

- Actually run `ralph-orchestrator.sh run`
- Watch an agent claim and implement a feature
- Create a real PR from an agent
- Test CI workflows
- Test the decision flow (agent asks question via Linear)

---

## Key Environment Variables

Already in `~/.zshrc`:
```bash
export LINEAR_API_KEY="lin_api_xxxxx"  # Your key (check ~/.zshrc)
export LINEAR_TEAM_ID="8acb3d44-3310-4676-b43b-835f4babedd7"
```

---

## Files to Know About

| File | Purpose |
|------|---------|
| `prd.json` | 6 features with Linear IDs |
| `STATUS.md` | Full system status |
| `ralph-scripts/ralph-linear.sh` | Linear API wrapper (fixed) |
| `ralph-scripts/ralph-orchestrator.sh` | Main entry point |
| `~/.zshrc` | Linear credentials |

---

## If Something Breaks

1. Check Linear connection: `./ralph-scripts/ralph-linear.sh test`
2. Check workflow states: `./ralph-scripts/ralph-linear.sh states`
3. Check prd.json has Linear IDs: `jq '.features[] | {id, linear_key}' prd.json`
4. Read STATUS.md for full context

---

## Goal

**Validate the system actually works** by running the orchestrator and watching what happens. Expect failures. Fix them. Iterate.
