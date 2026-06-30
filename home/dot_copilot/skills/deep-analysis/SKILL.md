---
name: deep-analysis
description: "Deep analysis of JIRA tickets including related tasks, Figma designs, Confluence docs, and command references to inform implementation research."
---

<!-- Source: IMG_2691–2693 — angled photos, transcription is best-effort. -->

# Deep Analysis Skill

## Purpose

Perform comprehensive research on a JIRA ticket to achieve 80%+ confidence in understanding requirements and implementation approach.

## Step 1: Fetch JIRA Data

### Action

- Extract JIRA ticket from JIRA URL or user input (e.g., BC724-550)
- Validate the issue key format

## Step 2: Analyze Related Issues

### Action

- Review comprehensive research on a JIRA ticket to achieve 80%+ confidence in understanding requirements and implementation approach.

## Step 3: Extract and Process URLs

### Action

- Identify URLs from JIRA fields (description, comments)
- Categorize URLs by source:
  - Figma URLs (design specs)
  - GitHub URLs (related PRs / commits)
  - Confluence URLs (docs)
  - Other (Slack, recordings, etc.)

## Step 4: Validate Confidence Score

### Decision Point

- self-confidence ≥ 80% → Generate research summary, recommend handoff to Plan Agent
- self-confidence < 80% → Identify gaps, ask user clarifying questions

## Step 5: Produce Output

Generate a structured research summary using the template in `research-summary-template.md`.

## Tools Required

- JIRA MCP (`mcp__atlassian__getJiraIssue`)
- Confluence MCP (`mcp__atlassian__searchConfluenceUsingCql`)
- Figma MCP (`mcp__figma__getFigmaData`)
- GitHub MCP (`mcp__github__getPullRequest`)
- Web fetch (for misc. links)

## Attributes

- `jiraTicket`: required JIRA key (e.g., BC724-550)
- `figmaUrls`: optional list of Figma links
- `confluenceUrls`: optional list of Confluence pages
- `prUrls`: optional list of related PRs
- `notes`: optional free-form context

## Files

- `SKILL.md` — this file
- `research-summary-template.md` — output template

## Returning a Goal

Return the populated research summary, with sources cited inline.
