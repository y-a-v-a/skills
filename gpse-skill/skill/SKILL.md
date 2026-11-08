---
name: google-search
description: "Deprecated: Google discontinues the Custom Search JSON API on 2027-01-01 and accepts no new customers. Searches the web through Google Programmable Search Engine with date, site, exact-phrase and exclusion filters. Runs only when invoked as /google-search; for everyday web search use the agent's built-in search."
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
argument-hint: "<query> [--date=w1] [--site=example.com] [--exact=phrase] [--exclude=terms]"
# Deprecated, and it would otherwise compete with the built-in WebSearch tool
# for every "search for…" request: user-invoked only.
disable-model-invocation: true
allowed-tools:
  - Bash
---

# Google Programmable Search Engine Skill

> **Deprecated.** Google closed the Custom Search JSON API to new customers
> and **discontinues it on 2027-01-01**
> ([overview](https://developers.google.com/custom-search/v1/overview)).
> Until then it works for existing API keys. From that date the script exits
> with a message saying so: report that to the user instead of troubleshooting
> credentials, and use the built-in web search if one is available.

This skill enables web search using Google's Programmable Search Engine. Its
remaining edge over a built-in web search is precise filtering: by date
(`--date`), by site, by exact phrase, and by exclusion.

## Setup

Requires environment variables:
- `GOOGLE_API_KEY` - Google API key with Custom Search API enabled
- `GOOGLE_CX` - Programmable Search Engine ID

## Usage

Execute searches with:

```bash
node <skill-dir>/scripts/search.js "search query here"
```

`<skill-dir>` is the directory this SKILL.md is in, not the current working
directory (that is the user's project, where `scripts/search.js` doesn't exist).

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

If a search fails due to missing GOOGLE_API_KEY or GOOGLE_CX environment variables
(only for existing API customers: Google no longer issues access to new ones):

1. Use AskUserQuestion to ask the user:
   - "Would you like help setting up the Google Search credentials?"
   - Options: "Yes, show setup instructions" / "No, I'll set them up later"

2. If user selects setup help:
   - Guide them through obtaining API key and Search Engine ID
   - Remind them to restart Claude Code after setting environment variables
