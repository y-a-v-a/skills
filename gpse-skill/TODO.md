# TODO: Google Programmable Search Engine Skill

## Phase 1: Core Implementation

### SKILL.md
- [x] Create SKILL.md file with YAML frontmatter
- [x] Add skill metadata (name, description, allowed-tools, user-invocable)
- [x] Write basic instructions for Claude
- [x] Add setup instructions (API key and cx configuration)
- [x] Document required environment variables (GOOGLE_API_KEY, GOOGLE_CX)
- [x] Add reference to scripts/search.js execution
- [x] Include basic usage examples

### scripts/search.js
- [x] Create scripts/ directory
- [x] Initialize search.js with proper Node.js structure
- [x] Implement URL construction for Google Custom Search API
- [x] Add API key and cx parameter handling
- [x] Implement query parameter encoding
- [x] Add fields parameter for response optimization
- [x] Implement HTTP request execution (fetch or https module)
- [x] Add JSON response parsing
- [x] Implement error handling for API errors (400, 401, 403, 429, 500)
- [x] Add error messages for missing credentials
- [x] Add error messages for quota exceeded
- [x] Add error messages for network errors
- [x] Implement response formatting to markdown
- [x] Format results with title, link, and snippet
- [x] Limit default results to 10 items
- [x] Add input sanitization for search queries

### Testing
- [x] Test with valid API key and cx
- [x] Test with missing credentials
- [x] Test with invalid API key
- [x] Test with quota exceeded scenario
- [x] Test response formatting
- [x] Test error handling paths

**Run tests with:** `node --test tests/search.test.js`

## Phase 2: Documentation

### examples/usage.md
- [x] Create examples/ directory
- [x] Create usage.md file
- [x] Add example: Basic search query
- [x] Add example: Direct invocation with /google-search
- [x] Add example: Search with specific fields
- [x] Add example: Handling no results
- [x] Add example: Error scenarios and recovery

### Setup Documentation
- [x] Document how to obtain Google API key
- [x] Document how to create Programmable Search Engine
- [x] Document how to get cx (Search Engine ID)
- [x] Add environment variable setup instructions
- [x] Add alternative configuration methods

### Troubleshooting Guide
- [x] Add section for "Skill not triggering"
- [x] Add section for "API authentication errors"
- [x] Add section for "Quota exceeded errors"
- [x] Add section for "No results returned"
- [x] Add section for "Invalid cx parameter"
- [x] Add links to Google API documentation

## Phase 3: Enhancement (Optional)

### Caching
- [ ] Design caching strategy for repeated queries
- [ ] Implement cache storage (in-memory or file-based)
- [ ] Add cache expiration logic
- [ ] Add cache key generation based on query
- [ ] Test cache hit/miss scenarios

### Pagination
- [x] Add support for startIndex parameter
- [x] Implement "next page" functionality
- [x] Add user instructions for requesting more results
- [x] Test pagination with multiple pages

### Advanced Parameters
- [x] Add dateRestrict parameter support
- [x] Add siteSearch parameter support
- [x] Add exactTerms parameter support
- [x] Add excludeTerms parameter support
- [x] Document advanced parameters in SKILL.md
- [x] Add examples for advanced usage

## General Tasks

- [x] Update README.md with skill installation instructions
- [ ] Add LICENSE file if needed
- [ ] Test skill integration with Claude Code
- [ ] Verify skill discovery and auto-activation
- [ ] Test user-invocable slash command
- [ ] Get user feedback and iterate
