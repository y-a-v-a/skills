---
name: google-search
description: Search the web using Google Programmable Search Engine. Use when you need to search for information online with custom search engine configuration.
allowed-tools:
  - Bash
user-invocable: true
---

# Google Programmable Search Engine Skill

This skill enables web search using Google's Programmable Search Engine.

## Setup

Requires environment variables:
- `GOOGLE_API_KEY` - Google API key with Custom Search API enabled
- `GOOGLE_CX` - Programmable Search Engine ID

## Usage

Execute searches with:

```bash
node scripts/search.js "search query here"
```

### Common Options

- `--num=N` - Number of results (1-10)
- `--start=N` - Starting index for pagination
- `--date=PERIOD` - Date filter (e.g., `w1` for last week, `m3` for 3 months)
- `--site=DOMAIN` - Restrict to specific domain
- `--exact=PHRASE` - Require exact phrase
- `--exclude=TERMS` - Exclude terms

See [reference.md](reference.md) for full parameter documentation and examples.

## Error Handling

- **Missing credentials**: Remind user to set GOOGLE_API_KEY and GOOGLE_CX
- **401/403 errors**: Invalid API key or cx
- **429 errors**: Daily quota exceeded (free tier: 100 queries/day)

## Missing Credentials Handling

If a search fails due to missing GOOGLE_API_KEY or GOOGLE_CX environment variables:

1. Use AskUserQuestion to ask the user:
   - "Would you like help setting up the Google Search credentials?"
   - Options: "Yes, show setup instructions" / "No, I'll set them up later"

2. If user selects setup help:
   - Guide them through obtaining API key and Search Engine ID
   - Remind them to restart Claude Code after setting environment variables
