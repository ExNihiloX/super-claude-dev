# Autonomous Claude Workflow with Ralph Wiggum, Linear, and Slack

## 1. Ralph Wiggum Method

The Ralph Wiggum technique is built into Claude Code via a plugin. It's an iterative loop where Claude continuously works on a task by seeing its own previous work.

**Available Commands:**
- `/ralph-loop "Your task prompt" --max-iterations 20 --completion-promise "DONE"` - Start a loop
- `/cancel-ralph` - Stop an active loop

**How it works:**
1. Claude receives the same prompt repeatedly
2. Work persists in files and git history
3. Claude sees previous attempts and iterates
4. Loop ends when Claude outputs `<promise>COMPLETION_TEXT</promise>` or hits max iterations

---

## 2. Linear Integration (Official MCP Server)

Linear announced their [official MCP server on May 1, 2025](https://linear.app/changelog/2025-05-01-mcp).

**Setup:**
```bash
# Option 1: Direct HTTP transport
claude mcp add --transport http linear-server https://mcp.linear.app/mcp

# Option 2: Using mcp-remote (recommended)
claude mcp add-json linear '{"command": "npx", "args": ["-y","mcp-remote","https://mcp.linear.app/sse"]}'
```

**Authentication:**
Run `/mcp` in Claude Code to complete the OAuth flow with Linear.

**Capabilities:**
- Search, create, and update issues
- Manage projects and comments
- Pull issue details and project status

**Sources:**
- [Linear MCP Docs](https://linear.app/docs/mcp)
- [Linear Claude Integration](https://linear.app/integrations/claude)
- [Setup Guide](https://www.jons.ink/2025/06/07/adding-linear-mcp-to-claude-code/)

---

## 3. Slack Integration

Several options exist for Slack notifications:

### Option A: Slack Notifications MCP Server (recommended for notifications)
```bash
# Install the notifications-focused MCP server
npx -y @anthropic/mcp install @Stig-Johnny/slack-notifications-mcp
```
Provides: `send_message()`, `get_channel_messages()`, `search_messages()`

### Option B: Full Slack MCP Server
```bash
claude mcp add-json slack '{"command": "npx", "args": ["-y", "@anthropic/slack-mcp"], "env": {"SLACK_BOT_TOKEN": "xoxb-your-token"}}'
```

### Option C: Claude Code Slack Bot
A dedicated Slack bot that connects to Claude Code SDK for bi-directional communication.
- [GitHub Repository](https://github.com/mpociot/claude-code-slack-bot)

### Option D: Webhook Hooks (simplest for notifications)
Add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "Notification": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "curl -X POST '$SLACK_WEBHOOK_URL' -H 'Content-type: application/json' -d '{\"text\":\"Claude notification: $NOTIFICATION_MESSAGE\"}'"
      }]
    }]
  }
}
```

**Sources:**
- [Slack MCP Server](https://glama.ai/mcp/servers/@ampcome-mcps/slack-mcp)
- [Slack Notifications MCP](https://glama.ai/mcp/servers/@Stig-Johnny/slack-notifications-mcp)
- [Composio Guide](https://composio.dev/blog/how-to-use-slack-mcp-server-with-claude-flawlessly)

---

## Recommended Workflow Setup

To achieve autonomous work with Linear tasks and Slack notifications:

### Step 1: Install Linear MCP
```bash
claude mcp add-json linear '{"command": "npx", "args": ["-y","mcp-remote","https://mcp.linear.app/sse"]}'
```

### Step 2: Install Slack MCP (or set up webhooks)
```bash
# Create Slack app at api.slack.com, get bot token
claude mcp add-json slack '{"command": "npx", "args": ["-y", "@anthropic/slack-mcp"], "env": {"SLACK_BOT_TOKEN": "xoxb-your-token"}}'
```

### Step 3: Run Ralph Loop with Linear + Slack
```bash
/ralph-loop "Check Linear for my assigned issues. Pick the highest priority incomplete task. Work on it. Send a Slack message to #dev-updates when you complete it or need help. Output <promise>CYCLE COMPLETE</promise> when done." --max-iterations 50
```

---

## Important Notes

1. **Remote MCP connections are new** - The Linear connection may fail occasionally; retry if needed
2. **Slack authentication** - You'll need to create a Slack app at [api.slack.com](https://api.slack.com) with appropriate bot scopes (`chat:write`, `channels:read`, etc.)
3. **Completion promises** - Your Ralph loop prompt MUST include clear success criteria and the `<promise>` tag for Claude to signal completion
4. **Safety** - Consider setting `--max-iterations` to prevent infinite loops

---

## Additional Resources

- [Ralph Wiggum Technique (Original)](https://ghuntley.com/ralph/)
- [Ralph Orchestrator](https://github.com/mikeyobrien/ralph-orchestrator)
- [Anthropic Remote MCP Announcement](https://www.anthropic.com/news/claude-code-remote-mcp)
- [MCP Protocol Documentation](https://modelcontextprotocol.io/)
