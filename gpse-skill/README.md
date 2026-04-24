# Google Programmable Search Engine Skill

A Claude Code skill that enables web search using Google's Programmable Search Engine (formerly Custom Search Engine/CSE).

## Features

- Search the web using Google Custom Search API
- Customizable search engine configuration
- Advanced filters: date, site, exact phrase, exclusions
- Pagination support for browsing results
- Formatted markdown output with title, link, and snippet
- Plain JavaScript with zero external dependencies

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- Node.js (v18 or later, for native fetch support)
- Google Cloud account with Custom Search API enabled
- A Programmable Search Engine ID (cx)

## Installation

### 1. Clone or Download This Repository

```bash
git clone https://github.com/nicovba/gpse-skill.git
```

### 2. Add the Skill to Claude Code

**Option A: Global skills (available in all projects)**
```bash
mkdir -p ~/.claude/skills
cp -r gpse-skill ~/.claude/skills/
```

**Option B: Project-local skills (available only in current project)**
```bash
mkdir -p .claude/skills
cp -r gpse-skill .claude/skills/
```

---

## Setup

### Step 1: Create a Google Cloud Project

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Sign in with your Google account
3. Click the project dropdown at the top of the page
4. Click **New Project**
5. Enter a project name (e.g., "Claude Search Skill")
6. Click **Create** and select the new project

### Step 2: Enable the Custom Search API

1. Go to **APIs & Services** > **Library**
2. Search for "Custom Search API"
3. Click on **Custom Search API** and click **Enable**

### Step 3: Create an API Key

1. Go to **APIs & Services** > **Credentials**
2. Click **+ CREATE CREDENTIALS** > **API key**
3. Copy the key immediately
4. (Recommended) Click **Edit API key**, select **Restrict key**, check only **Custom Search API**, and save

**Important:** Keep your API key secure. Do not commit it to version control.

### Step 4: Create a Programmable Search Engine

1. Go to [Programmable Search Engine](https://programmablesearchengine.google.com/)
2. Click **Get started** or **Add**
3. Choose one:
   - **Search the entire web** — for general searches
   - **Search specific sites** — for targeted searches (e.g., `stackoverflow.com`, `github.com`)
4. Name your engine and click **Create**

### Step 5: Get Your Search Engine ID (cx)

1. After creating the engine, click **Customize** or go to the control panel
2. In the **Overview** section, find and copy the **Search engine ID**
   (looks like: `017576662512468239146:omuauf_lfve`)

### Step 6: Configure Environment Variables

```bash
export GOOGLE_API_KEY="your-api-key-here"
export GOOGLE_CX="your-search-engine-id-here"
```

To make these persistent, add them to your shell profile:

**Bash (~/.bashrc):**
```bash
echo 'export GOOGLE_API_KEY="your-api-key-here"' >> ~/.bashrc
echo 'export GOOGLE_CX="your-search-engine-id-here"' >> ~/.bashrc
source ~/.bashrc
```

**Zsh (~/.zshrc):**
```bash
echo 'export GOOGLE_API_KEY="your-api-key-here"' >> ~/.zshrc
echo 'export GOOGLE_CX="your-search-engine-id-here"' >> ~/.zshrc
source ~/.zshrc
```

**Fish (~/.config/fish/config.fish):**
```fish
set -Ux GOOGLE_API_KEY "your-api-key-here"
set -Ux GOOGLE_CX "your-search-engine-id-here"
```

### Alternative Configuration Methods

**Using a .env file** (add `.env` to `.gitignore`):
```bash
GOOGLE_API_KEY=your-api-key-here
GOOGLE_CX=your-search-engine-id-here
```

**Using [direnv](https://direnv.net/):**
```bash
# .envrc
export GOOGLE_API_KEY="your-api-key-here"
export GOOGLE_CX="your-search-engine-id-here"
```
Then run `direnv allow`.

### Verify Your Setup

```bash
echo $GOOGLE_API_KEY
echo $GOOGLE_CX
node scripts/search.js "test query"
```

### Security Best Practices

1. **Never commit API keys** — add `.env` to `.gitignore`
2. **Restrict your API key** — limit it to only the Custom Search API
3. **Monitor usage** — check the Google Cloud Console for unexpected activity
4. **Rotate keys periodically** — delete and recreate if compromised

---

## Usage

### Direct Invocation

```
/google-search machine learning papers 2026
```

### Natural Language

Simply ask Claude to search:
```
Search for recent developments in quantum computing
```

### Limiting Results

```bash
node scripts/search.js "Python tutorials" --num=5
```

### Date Filtering

Restrict results by time period:

```bash
node scripts/search.js "AI news" --date=w1
```

Date formats: `d[N]` (days), `w[N]` (weeks), `m[N]` (months), `y[N]` (years).

### Site-Specific Search

```bash
node scripts/search.js "React hooks" --site=github.com
node scripts/search.js "Python error handling" --site=stackoverflow.com
```

### Exact Phrase Matching

```bash
node scripts/search.js "machine learning" --exact=best practices
```

### Excluding Terms

```bash
node scripts/search.js "JavaScript tutorial" --exclude=beginner
```

### Combining Filters

```bash
node scripts/search.js "Python machine learning" --date=m3 --site=arxiv.org --num=5
```

### Pagination

```bash
# First page (results 1-10)
node scripts/search.js "quantum computing"

# Second page (results 11-20)
node scripts/search.js "quantum computing" --start=11
```

Google Custom Search allows up to 100 results per query (start index up to 91 with 10 results).

### Tips for Best Results

- **Be specific** — more specific queries yield more relevant results
- **Include year** — add the year to find recent content
- **Limit results** — use `--num=3` or `--num=5` for quick overviews

### Response Format

```markdown
## Search Results for: "query"

1. **Result Title**
   https://example.com/page
   Description snippet from the page...

2. **Another Result**
   https://example.com/other
   Another description...
```

---

## Configuration

| Environment Variable | Required | Description |
|---------------------|----------|-------------|
| `GOOGLE_API_KEY` | Yes | Google API key with Custom Search API enabled |
| `GOOGLE_CX` | Yes | Programmable Search Engine ID |

---

## Quotas and Limits

| Tier | Daily Limit | Cost |
|------|-------------|------|
| Free | 100 queries | $0 |
| Paid | 10,000 queries | $5 per 1,000 queries |

Quota resets at midnight Pacific Time. To check usage: **Google Cloud Console** > **APIs & Services** > **Dashboard** > **Custom Search API** > **Metrics**.

For details, see [Google Custom Search pricing](https://developers.google.com/custom-search/v1/overview#pricing).

---

## Troubleshooting

### Quick Diagnostic Checklist

```bash
echo "API Key: ${GOOGLE_API_KEY:0:10}..."   # Shows first 10 chars
echo "CX: $GOOGLE_CX"
ls -la scripts/search.js
node --version
node scripts/search.js "test"
```

### Error Reference

| Error | Likely Cause | Fix |
|-------|--------------|-----|
| `GOOGLE_API_KEY not set` | Missing env var | `export GOOGLE_API_KEY="..."` |
| `GOOGLE_CX not set` | Missing env var | `export GOOGLE_CX="..."` |
| `401 Unauthorized` | Invalid API key | Verify key in [Cloud Console](https://console.cloud.google.com/apis/credentials) |
| `403 Forbidden` | API not enabled or key restricted | Enable Custom Search API; check key restrictions |
| `403 quota exceeded` | Daily limit reached | Wait for midnight PT reset or enable billing |
| `429 Too Many Requests` | Rate limited | Wait and retry |
| `No results found` | Query too specific or typos | Try different/broader search terms |
| `Network error` | No connectivity | Check internet; verify `googleapis.com` is reachable |

### Skill Not Triggering

- Verify `SKILL.md` and `scripts/search.js` exist in the project
- Check YAML frontmatter in `SKILL.md` for syntax errors
- Restart Claude Code to trigger skill discovery
- Use `/google-search query` (not `google-search query`)

### Common Quick Fixes

1. Restart your terminal to reload environment variables
2. Re-source your shell config: `source ~/.bashrc` or `source ~/.zshrc`
3. Re-copy credentials without extra whitespace
4. Ensure the correct Google Cloud project is selected

### Getting Help

- [Custom Search API Overview](https://developers.google.com/custom-search/v1/overview)
- [Custom Search API Reference](https://developers.google.com/custom-search/v1/reference/rest/v1/cse/list)
- [Programmable Search Engine Help](https://support.google.com/programmable-search/)
- [API Credentials](https://console.cloud.google.com/apis/credentials)

---

## API Reference

### Basic REST API Request

```http
GET https://www.googleapis.com/customsearch/v1?key=YOUR_API_KEY&cx=YOUR_CX&q=lectures
```

### Field Selection for Efficiency

Use the `fields` parameter to limit response size:

```
https://www.googleapis.com/customsearch/v1?q=google&fields=kind,items(title,link,snippet)
```

Response:
```json
{
  "kind": "customsearch#search",
  "items": [
    {
      "title": "Google",
      "link": "https://www.google.com/",
      "snippet": "Search the world's information..."
    }
  ]
}
```

See [reference.md](skill/reference.md) for full parameter documentation.

---

## Support

[Buy Vincent Bruijn a coffee](https://buymeacoffee.com/y4v4)
