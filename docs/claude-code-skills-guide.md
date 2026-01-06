# Complete Guide to Claude Code Skills

## What Are Skills?

**Skills** are markdown files (with optional scripts and resources) that teach Claude how to perform specific tasks. They extend Claude's capabilities with domain-specific expertise, workflows, and best practices.

**Key characteristics:**
- **Model-invoked**: Claude automatically decides when to use them based on your request
- **Reusable**: Create once, use across all conversations
- **Composable**: Combine multiple Skills for complex workflows
- **Progressive disclosure**: Only loads what's needed, saving context tokens

---

## How Skills Work

When you send a request, Claude follows a three-stage process:

1. **Discovery** (at startup): Only Skill names and descriptions are loaded
2. **Activation**: When your request matches a Skill's description, Claude asks permission and loads the full `SKILL.md`
3. **Execution**: Claude follows the Skill's instructions, reading supporting files or running scripts as needed

---

## Setting Up Skills on Your Computer

### Directory Locations

| Scope | Location | Who Can Use |
|-------|----------|-------------|
| **Personal** | `~/.claude/skills/skill-name/` | You only, all projects |
| **Project** | `.claude/skills/skill-name/` | Team members in repo |
| **Plugin** | Installed via `/plugin install` | Plugin users |

### Creating Your First Skill

**Step 1: Create the directory**
```bash
# Personal skill
mkdir -p ~/.claude/skills/my-skill

# Project skill (shared with team)
mkdir -p .claude/skills/my-skill
```

**Step 2: Create SKILL.md**
```yaml
---
name: my-skill-name
description: Brief description of what this Skill does and when to use it. Include trigger keywords users might say.
---

# My Skill Name

## Instructions
Provide clear, step-by-step guidance for Claude.

## Examples
Show concrete examples of using this Skill.
```

**Step 3: Restart Claude Code**
Exit and restart Claude Code to load the new skill.

**Step 4: Verify**
Ask: "What Skills are available?"

### YAML Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (max 64 chars, lowercase, hyphens allowed) |
| `description` | Yes | What the Skill does and when to use it (max 1024 chars) |
| `allowed-tools` | No | Restrict Claude to specific tools (e.g., `Read, Grep, Glob`) |
| `model` | No | Override model (e.g., `claude-opus-4-5-20251101`) |

### Multi-File Skill Structure

For complex skills:
```
my-skill/
├── SKILL.md              # Overview (required, keep under 500 lines)
├── reference.md          # Detailed reference (loaded as needed)
├── examples.md           # Usage examples
└── scripts/
    ├── validate.py       # Utility scripts
    └── process.py
```

---

## Installing Skills from Marketplaces

### Official Anthropic Skills
```bash
# Document skills (docx, pdf, pptx, xlsx)
/plugin install document-skills@anthropic-agent-skills

# Example skills collection
/plugin install example-skills@anthropic-agent-skills
```

### Community Skills
Browse and install from:
- [SkillsMP](https://skillsmp.com/) - 25,000+ skills
- [Awesome Claude Skills](https://github.com/travisvn/awesome-claude-skills) - Curated list
- [Claude Skills Library](https://mcpservers.org/claude-skills)

---

## Best Practices

### 1. Write Discoverable Descriptions
**Good:**
```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

**Bad:**
```yaml
description: Helps with documents
```

### 2. Keep SKILL.md Concise
- Aim for under 500 lines
- Use progressive disclosure (link to separate files for details)
- Challenge every paragraph: "Does Claude really need this?"

### 3. Use Clear Instructions
- Step-by-step numbered lists
- Code examples showing exact usage
- Concrete workflows with checklists

### 4. Bundle Scripts, Don't Generate Code
```markdown
## Validate forms
Run: `python scripts/validate_form.py input.pdf`
```

---

## Recommended Skills for Software Product Development

### Official Development Skills

| Skill | Description | Install Command |
|-------|-------------|-----------------|
| **artifacts-builder** | Build complex HTML artifacts with React and Tailwind | `/plugin install example-skills@anthropic-agent-skills` |
| **mcp-builder** | Create high-quality MCP servers | `/plugin install example-skills@anthropic-agent-skills` |
| **webapp-testing** | Test web applications using Playwright | `/plugin install example-skills@anthropic-agent-skills` |
| **frontend-design** | Make bold design decisions, avoid generic aesthetics | `/plugin install example-skills@anthropic-agent-skills` |

### Community Development Skills

| Skill | Purpose | Source |
|-------|---------|--------|
| **obra/superpowers** | 20+ battle-tested skills: TDD, debugging, collaboration patterns | [GitHub](https://github.com/obra/superpowers) |
| **Feature Planner** | Break down feature requests into implementable plans | SkillsMP |
| **Git Automation** | Auto-stage, commit with conventional messages, push | SkillsMP |
| **Test Fixer** | Systematically identify and fix failing tests | SkillsMP |
| **Code Review** | Process and implement code review feedback | SkillsMP |
| **ios-simulator-skill** | iOS app automation and testing | Community |
| **playwright-skill** | General browser automation | Community |
| **claude-d3js-skill** | D3.js data visualizations | Community |

### Custom Skill Ideas for Software Development

**1. PR Review Workflow**
```yaml
---
name: pr-review-workflow
description: Review pull requests systematically. Use when reviewing PRs, checking code quality, or preparing merge requests.
---

# PR Review Workflow

1. Check for breaking changes in API contracts
2. Verify test coverage for new code
3. Review for security vulnerabilities (OWASP top 10)
4. Check adherence to project conventions in CLAUDE.md
5. Verify documentation is updated
```

**2. Release Notes Generator**
```yaml
---
name: release-notes-generator
description: Generate release notes from git commits. Use when preparing releases or creating changelogs.
---

# Release Notes Generator

1. Run `git log --oneline v{last}..HEAD`
2. Group by: Features, Bug Fixes, Breaking Changes
3. Include PR numbers and authors
4. Format in Keep a Changelog style
```

---

## Recommended Skills for Brick and Mortar Business

### Official Document Skills

Essential for any business handling paperwork:

| Skill | Description | Use Cases |
|-------|-------------|-----------|
| **xlsx** | Create/edit Excel spreadsheets with formulas | Inventory tracking, sales reports, financial projections |
| **docx** | Create/edit Word documents with tracked changes | Contracts, employee handbooks, policies |
| **pdf** | Extract text, fill forms, merge documents | Invoice processing, form filling, document archives |
| **pptx** | Create PowerPoint presentations | Investor decks, training materials, sales presentations |

**Install all document skills:**
```bash
/plugin install document-skills@anthropic-agent-skills
```

### Business Operations Skills

| Skill | Purpose | Source |
|-------|---------|--------|
| **Invoice Organizer** | Organize invoices/receipts for tax prep | Community |
| **internal-comms** | Write status reports, newsletters, FAQs | Anthropic |
| **brand-guidelines** | Apply brand colors and typography | Anthropic |
| **Meeting Prep** | Prepare meeting materials from Notion context | Community |

### Custom Skill Ideas for Brick and Mortar

**1. Daily Sales Report**
```yaml
---
name: daily-sales-report
description: Generate daily sales reports from POS data. Use when creating sales summaries, end-of-day reports, or analyzing daily performance.
---

# Daily Sales Report Generator

## Instructions
1. Read the CSV export from POS system
2. Calculate total revenue, transaction count, average ticket
3. Compare to same day last week/month/year
4. Highlight top-selling items
5. Flag any anomalies (returns, voids, discounts)

## Output Format
- Summary table with KPIs
- Top 10 products by revenue
- Hourly sales breakdown
- Notes on variances
```

**2. Inventory Reorder Alert**
```yaml
---
name: inventory-reorder
description: Analyze inventory levels and generate reorder recommendations. Use when checking stock levels, creating purchase orders, or planning inventory.
---

# Inventory Reorder System

## Instructions
1. Read current inventory spreadsheet
2. Compare against minimum stock levels
3. Check sales velocity (last 30 days)
4. Calculate reorder quantities based on lead times
5. Generate purchase order draft

## Reorder Formula
`Reorder Qty = (Daily Sales Rate × Lead Time Days) + Safety Stock - Current Stock`
```

**3. Employee Schedule Generator**
```yaml
---
name: employee-scheduler
description: Create weekly employee schedules based on availability and labor requirements. Use when scheduling staff, planning shifts, or managing labor costs.
---

# Employee Schedule Generator

## Inputs Needed
- Employee availability (from shared spreadsheet)
- Labor budget (hours per day)
- Peak hours requirements
- Time-off requests

## Rules
1. No employee works more than 8 hours/day
2. Minimum 2 staff during peak hours (11am-2pm, 5pm-8pm)
3. At least one senior staff per shift
4. Respect availability constraints
```

**4. Customer Communication Templates**
```yaml
---
name: customer-comms
description: Generate customer communications for promotions, updates, and follow-ups. Use when writing marketing emails, SMS campaigns, or customer notifications.
---

# Customer Communications

## Email Templates
- New product announcement
- Sale/promotion notification
- Loyalty program update
- Thank you/follow-up
- Review request

## SMS Templates (160 char limit)
- Flash sale alert
- Order ready for pickup
- Appointment reminder

## Tone
Professional but warm. Use customer's first name. Include clear call-to-action.
```

**5. Monthly Financial Summary**
```yaml
---
name: monthly-financials
description: Create monthly financial summaries from accounting exports. Use when preparing financial reports, analyzing profitability, or reviewing monthly performance.
---

# Monthly Financial Summary

## Process
1. Import P&L from QuickBooks/Xero export
2. Calculate key ratios:
   - Gross margin %
   - Labor cost %
   - Rent/revenue ratio
   - Net profit margin
3. Compare to budget and prior year
4. Identify cost variances > 10%
5. Generate executive summary

## Output
- One-page financial dashboard
- Variance analysis
- Cash flow projection for next month
```

---

## Combining Skills with MCP for Maximum Power

Skills tell Claude **how** to use tools; MCP provides **the tools**.

### Example: Inventory Management System

**MCP Server:** Connect to your inventory database
```bash
claude mcp add-json inventory '{"command": "npx", "args": ["-y", "inventory-mcp-server"], "env": {"DB_URL": "your-database-url"}}'
```

**Skill:** Teach Claude your inventory workflows
```yaml
---
name: inventory-management
description: Manage inventory using our database. Use when checking stock, updating quantities, or generating reports.
---

# Inventory Management

## Database Schema
- products: id, name, sku, category, cost, price
- inventory: product_id, location_id, quantity, min_level
- transactions: id, product_id, type, quantity, timestamp

## Common Operations
- Check stock: Query inventory table with product_id
- Low stock alert: WHERE quantity < min_level
- Update quantity: INSERT transaction, UPDATE inventory
```

### Example: Customer Communication System

**MCP Server:** Connect to Slack and email
```bash
claude mcp add-json slack '{"command": "npx", "args": ["-y", "slack-mcp"], "env": {"SLACK_TOKEN": "..."}}'
```

**Skill:** Define communication workflows
```yaml
---
name: customer-outreach
description: Send customer communications via appropriate channels. Use when sending promotions, updates, or notifications.
---

# Customer Outreach

## Channel Selection
- Urgent (same-day): SMS
- Promotional: Email
- Internal team: Slack #customer-updates

## Approval Required
- Discounts > 20%
- New product launches
- Policy changes
```

---

## Skills + Ralph Wiggum + Linear + Slack

Combine everything for autonomous business operations:

```bash
/ralph-loop "Check Linear for business operations tasks. Use the inventory-management skill to check stock levels. Use the daily-sales-report skill to generate reports. Send updates to #business-ops in Slack. Output <promise>DAILY OPS COMPLETE</promise> when done." --max-iterations 30
```

---

## Resources

### Official Documentation
- [Agent Skills Documentation](https://code.claude.com/docs/en/skills)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)
- [Building Skills for Claude Code](https://claude.com/blog/building-skills-for-claude-code)

### Marketplaces
- [SkillsMP](https://skillsmp.com/) - 25,000+ agent skills
- [Awesome Claude Skills](https://github.com/travisvn/awesome-claude-skills) - Curated list
- [Claude Skills Library](https://mcpservers.org/claude-skills)

### Tutorials
- [How to Create Custom Skills](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills)
- [DataCamp Skills Tutorial](https://www.datacamp.com/tutorial/claude-skills)
- [Skywork Step-by-Step Guide](https://skywork.ai/blog/ai-agent/how-to-create-claude-skill-step-by-step-guide/)

### Community Collections
- [obra/superpowers](https://github.com/obra/superpowers) - 20+ battle-tested skills
- [mhattingpete/claude-skills-marketplace](https://github.com/mhattingpete/claude-skills-marketplace) - Git automation, testing, code review

---

## Quick Reference

### Create a Personal Skill
```bash
mkdir -p ~/.claude/skills/my-skill
cat > ~/.claude/skills/my-skill/SKILL.md << 'EOF'
---
name: my-skill
description: Description with trigger keywords
---

# Instructions here
EOF
```

### Create a Project Skill (Team)
```bash
mkdir -p .claude/skills/my-skill
# Create SKILL.md
git add .claude/skills/
git commit -m "Add custom skill"
```

### Install Official Skills
```bash
/plugin install document-skills@anthropic-agent-skills
/plugin install example-skills@anthropic-agent-skills
```

### Check Available Skills
Ask Claude: "What Skills are available?"

### Skill Won't Trigger?
Make your description more specific with keywords users would naturally say.
