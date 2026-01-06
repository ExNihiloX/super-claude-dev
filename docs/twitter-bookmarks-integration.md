# Twitter/X API Bookmarks Integration with Claude Code

## Twitter/X API - Bookmarks Access

### Official API Endpoint
- **Endpoint**: `GET /2/users/{id}/bookmarks`
- **Returns**: Up to 800 of your most recent bookmarks
- **Rate limit**: 50 requests per 15 minutes
- **Required scopes**: `tweet.read`, `users.read`, `bookmark.read`

Source: [X Developer Platform - Get Bookmarks](https://docs.x.com/x-api/users/get-bookmarks)

### API Pricing (The Catch)

| Tier | Price | Bookmark Access |
|------|-------|-----------------|
| Free | $0 | No read access |
| Basic | $200/month | Limited |
| Pro | $5,000/month | Full access |
| Pay-per-use | Beta (closed) | Per-call pricing |

**Important**: The Free tier doesn't allow reading data, only posting. You need at least Basic ($200/mo) for bookmark access.

Sources:
- [Twitter API Pricing 2025](https://twitterapi.io/blog/twitter-api-pricing-2025)
- [Complete Cost Breakdown](https://getlate.dev/blog/twitter-api-pricing)

---

## MCP Servers for Twitter Bookmarks

### Option 1: x-twitter-mcp-server (Full API Access)

Real-time bookmark management via official API.

**GitHub**: https://github.com/rafaljanicki/x-twitter-mcp-server

**Features:**
- Fetch bookmarks
- Add/remove bookmarks
- Delete all bookmarks
- Plus: profiles, timelines, search, posting

**Setup:**
```bash
claude mcp add-json twitter '{"command": "npx", "args": ["-y", "x-twitter-mcp-server"], "env": {"TWITTER_API_KEY": "...", "TWITTER_API_SECRET": "...", "TWITTER_ACCESS_TOKEN": "...", "TWITTER_ACCESS_SECRET": "..."}}'
```

**Requirement**: Paid API tier ($200+/month)

---

### Option 2: twitter-bookmark-mcp (SQLite Export - FREE)

Export bookmarks to SQLite database for Claude to query.

**GitHub**: https://github.com/chrislee973/twitter-bookmark-mcp

**How it works:**
1. Use their web tool to export your bookmarks to SQLite
2. Download the database file
3. Claude queries it locally

**Example prompts:**
- "Look through my twitter bookmarks for posts about AI and summarize them"
- "Create a chart of my bookmark frequency over time"
- "Find all bookmarks with links to specific blogs"

**No API cost** - uses browser automation to export.

---

### Option 3: fetch-twitter-bookmarks (CLI Export - FREE)

Headless browser tool that exports bookmarks to SQLite/JSON.

**GitHub**: https://github.com/helmetroo/fetch-twitter-bookmarks

```bash
npx fetch-twitter-bookmarks
```

**Output**: SQLite database or JSON files you can feed to Claude.

---

## Recommended Setup for Builds Context

### Free Method (Manual Export)

1. **Export bookmarks** using `twitter-bookmark-mcp` or `fetch-twitter-bookmarks`
2. **Store as SQLite/JSON** in your project
3. **Create a Skill** to help Claude understand your bookmarks:

```yaml
---
name: twitter-bookmarks-context
description: Access saved Twitter bookmarks for build inspiration and reference. Use when the user mentions bookmarks, saved tweets, or inspiration from Twitter.
---

# Twitter Bookmarks Context

## Location
Bookmarks are stored in: `./data/twitter-bookmarks.db`

## How to Query
```sql
SELECT * FROM bookmarks WHERE text LIKE '%keyword%';
```

## Use Cases
- Find saved code snippets/tutorials
- Reference product ideas
- Pull design inspiration
- Recall technical threads
```

### Paid Method (Real-time Access)

1. Get Twitter API Basic tier ($200/month)
2. Install `x-twitter-mcp-server`
3. Claude can read/manage bookmarks live

---

## Quick Reference

| Question | Answer |
|----------|--------|
| Does Twitter have an API? | Yes |
| Can you access bookmarks? | Yes, via `GET /2/users/{id}/bookmarks` |
| Is it free? | No - requires $200+/month API tier |
| Free alternatives? | Yes - export via browser tools to SQLite/JSON |
| Can Claude use them? | Yes - via MCP server or local database + Skill |

---

## Additional Resources

- [Bookmarks Introduction](https://developer.x.com/en/docs/x-api/tweets/bookmarks/introduction)
- [Bookmarks Integration Guide](https://developer.x.com/en/docs/x-api/tweets/bookmarks/integrate)
- [X MCP Server on LobeHub](https://lobehub.com/mcp/rafaljanicki-x-twitter-mcp-server)
- [Twitter MCP on ClaudeLog](https://claudelog.com/claude-code-mcps/twitter-mcp/)
