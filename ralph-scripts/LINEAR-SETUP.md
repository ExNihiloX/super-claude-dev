# Linear Integration Setup Guide

This guide walks you through setting up Linear as the communication platform for Ralph.

## Why Linear over Slack?

| Feature | Linear | Slack |
|---------|--------|-------|
| Feature tracking | Native issues | Chat messages |
| Status transitions | Built-in states | Manual updates |
| Decision audit trail | Issue comments | Buried in chat |
| Dependencies | Native support | None |
| Mobile notifications | Yes | Yes |
| Context preservation | Always visible | Scrolls away |

## Quick Start

### 1. Get Linear API Key

1. Go to [Linear Settings](https://linear.app/settings/api)
2. Click "Personal API keys"
3. Create new key with label "Ralph"
4. Copy the key (starts with `lin_api_`)

### 2. Find Your Team ID

Run this after setting your API key:
```bash
export LINEAR_API_KEY="lin_api_xxxxx"
./ralph-scripts/ralph-linear.sh teams
```

Copy your team ID (UUID format).

### 3. Configure Ralph

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export LINEAR_API_KEY="lin_api_your_key_here"
export LINEAR_TEAM_ID="your-team-uuid-here"
```

Or create a `.env` file in your project:
```bash
LINEAR_API_KEY=lin_api_your_key_here
LINEAR_TEAM_ID=your-team-uuid-here
```

### 4. Test Connection

```bash
source ~/.zshrc  # or restart terminal
./ralph-scripts/ralph-linear.sh test
```

You should see: `Connected as: Your Name`

### 5. List Workflow States

```bash
./ralph-scripts/ralph-linear.sh states
```

**Important:** Ensure you have a "Blocked" state in your workflow. If not, add it:
1. Linear Settings → Teams → Your Team → Workflow
2. Add "Blocked" state between "In Progress" and "Done"

---

## Tested Configuration (AURA Team)

This configuration has been tested and verified working:

```bash
# ~/.zshrc
export LINEAR_API_KEY="lin_api_xxxxx"  # Your actual key
export LINEAR_TEAM_ID="8acb3d44-3310-4676-b43b-835f4babedd7"  # AURA team
```

**Workflow States (AURA):**
- Backlog (backlog)
- Todo (unstarted)
- In Progress (started)
- Blocked (started)
- In Review (started)
- Done (completed)
- Canceled (canceled)
- Duplicate (canceled)

---

## Workflow

### When You Run `/prd-generator`

Ralph will:
1. Generate feature specs in `prd.json`
2. Create a Linear issue for each feature
3. Store `linear_id` in each feature object
4. Set initial status to "Backlog"

### When Agents Work

For each feature:
- **Claimed**: Issue → "In Progress", comment added
- **Blocked**: Issue → "Blocked", decision request comment
- **Completed**: Issue → "In Review", PR link comment

### When You Need to Decide

1. You'll see issue in "Blocked" state
2. Read the decision request in comments
3. Reply with your choice (e.g., "1" or "Go with JWT")
4. Agent detects your comment and continues

---

## Linear Issue States

Ralph uses these standard Linear states:

| State | Meaning |
|-------|---------|
| Backlog | Feature defined, not started |
| Todo | Ready to be claimed |
| In Progress | Agent actively working |
| Blocked | Waiting for human decision |
| In Review | PR created, awaiting review |
| Done | Merged and complete |

---

## Commands

### ralph-linear.sh

```bash
# Test connection
./ralph-scripts/ralph-linear.sh test

# List teams
./ralph-scripts/ralph-linear.sh teams

# List workflow states for team
./ralph-scripts/ralph-linear.sh states

# Create issue
./ralph-scripts/ralph-linear.sh create "Issue title" "Description"

# Update issue status
./ralph-scripts/ralph-linear.sh status <issue-id> <state-name>

# Add comment
./ralph-scripts/ralph-linear.sh comment <issue-id> "Comment text"

# Get issue details
./ralph-scripts/ralph-linear.sh get <issue-id>

# List comments on issue
./ralph-scripts/ralph-linear.sh comments <issue-id>

# Poll for new comments (for decisions)
./ralph-scripts/ralph-linear.sh poll <issue-id> <since-timestamp>
```

### ralph-linear-sync.sh

```bash
# Create Linear issues from prd.json
./ralph-scripts/ralph-linear-sync.sh init

# Sync status from Linear back to prd.json
./ralph-scripts/ralph-linear-sync.sh pull

# Push local status changes to Linear
./ralph-scripts/ralph-linear-sync.sh push
```

---

## Advanced Configuration

### Custom State Mapping

If your Linear team uses different state names, configure mapping:

```bash
export LINEAR_STATE_BACKLOG="Backlog"
export LINEAR_STATE_TODO="Todo"
export LINEAR_STATE_IN_PROGRESS="In Progress"
export LINEAR_STATE_BLOCKED="Blocked"
export LINEAR_STATE_IN_REVIEW="In Review"
export LINEAR_STATE_DONE="Done"
```

### Project Organization

By default, Ralph creates issues at the team level. To use a specific project:

```bash
export LINEAR_PROJECT_ID="your-project-uuid"
```

### Labels

Ralph can auto-label issues:

```bash
export LINEAR_LABEL_RALPH="ralph-managed"  # Label name to apply
```

---

## Troubleshooting

### "Unauthorized" error
- Check your API key is valid
- Ensure it hasn't expired
- Verify it has the right permissions

### "POST body missing" or JSON errors
- This was fixed in the 2026-01-07 update
- Ensure you have the latest `ralph-linear.sh`
- The fix uses temp files to avoid shell escaping issues

### Issues not appearing
- Check team ID is correct
- Verify project ID if using one
- Check Linear's web interface directly

### Comments not detected
- Agent polls every 30 seconds by default
- Ensure you're commenting on the right issue
- Check the comment isn't from a bot/integration

### "State not found" error
- Run `./ralph-scripts/ralph-linear.sh states` to see available states
- Ensure "Blocked" state exists in your workflow
- Check state name matches exactly (case-sensitive)

---

## Security Notes

- API key has full access to your Linear workspace
- Keep it secret (don't commit to git)
- Use environment variables or secrets manager
- Consider creating a dedicated "Ralph" user for audit clarity
