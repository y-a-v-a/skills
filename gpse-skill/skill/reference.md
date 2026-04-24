# Google Search Skill Reference

## Parameters

The search script accepts the following parameters:

### Basic Parameters
- `--num=N` - Number of results (default: 10, max: 10 per request)
- `--start=N` - Starting index for results, enables pagination (default: 1, max: 91)

### Advanced Search Filters
- `--date=PERIOD` - Restrict results by date. Format: `d[N]` (days), `w[N]` (weeks), `m[N]` (months), `y[N]` (years)
  - Examples: `d1` (last day), `w1` (last week), `m3` (last 3 months), `y1` (last year)
- `--site=DOMAIN` - Restrict results to a specific domain
  - Example: `github.com`, `stackoverflow.com`
- `--exact=PHRASE` - Require this exact phrase to appear in results
- `--exclude=TERMS` - Exclude results containing these terms

## Pagination

To retrieve additional results beyond the first page, use the `--start` parameter:

```bash
# First page (results 1-10)
node scripts/search.js "quantum computing"

# Second page (results 11-20)
node scripts/search.js "quantum computing" --start=11

# Third page (results 21-30)
node scripts/search.js "quantum computing" --start=21
```

**Note:** Google Custom Search API allows a maximum of 100 results per query (start index up to 91 with 10 results).

## Examples

### Basic Search
User: "Search for recent developments in quantum computing"
```bash
node scripts/search.js "recent developments quantum computing 2026"
```

### Direct Invocation
User: "/google-search machine learning papers"
```bash
node scripts/search.js "machine learning papers"
```

### Search with Limited Results
```bash
node scripts/search.js "machine learning papers" --num=5
```

### Search Recent Content
User: "Find news about AI from the last week"
```bash
node scripts/search.js "AI news" --date=w1
```

### Site-Specific Search
User: "Search for Python tutorials on Stack Overflow"
```bash
node scripts/search.js "Python tutorial" --site=stackoverflow.com
```

### Require Exact Phrase
```bash
node scripts/search.js "programming" --exact=best practices
```

### Exclude Unwanted Results
User: "Find JavaScript frameworks but not React"
```bash
node scripts/search.js "JavaScript framework" --exclude=React
```

### Combined Filters
User: "Find recent machine learning papers on arxiv"
```bash
node scripts/search.js "machine learning" --date=m1 --site=arxiv.org --num=5
```

## Response Format

The search returns results formatted as markdown:

```
## Search Results for: "query"

1. **Result Title**
   https://example.com/page
   Description snippet from the page...

2. **Another Result**
   https://example.com/other
   Another description...
```

## Error Codes

| Error | Cause |
|-------|-------|
| Missing credentials | GOOGLE_API_KEY or GOOGLE_CX not set |
| 401 Unauthorized | Invalid API key |
| 403 Forbidden | API key lacks permission or invalid cx |
| 429 Too Many Requests | Daily quota exceeded (free tier: 100/day) |

See [README.md](../README.md#troubleshooting) for detailed solutions.
