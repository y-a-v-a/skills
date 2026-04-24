#!/usr/bin/env node

/**
 * Google Programmable Search Engine Script
 *
 * Searches the web using Google Custom Search API and returns formatted results.
 *
 * Usage: node search.js "search query" [--num=N] [--start=N] [--date=PERIOD] [--site=DOMAIN] [--exact=PHRASE] [--exclude=TERMS]
 *
 * Environment variables required:
 *   GOOGLE_API_KEY - Google API key with Custom Search API enabled
 *   GOOGLE_CX - Programmable Search Engine ID
 */

const API_ENDPOINT = 'https://www.googleapis.com/customsearch/v1';
const DEFAULT_FIELDS = 'kind,items(title,link,snippet)';
const DEFAULT_NUM_RESULTS = 10;
const DEFAULT_START_INDEX = 1;

/**
 * Sanitizes user input to prevent injection attacks
 * @param {string} input - Raw user input
 * @returns {string} Sanitized input
 */
function sanitizeInput(input) {
  if (typeof input !== 'string') {
    return '';
  }
  // Remove null bytes and control characters (except common whitespace)
  return input.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '').trim();
}

/**
 * Validates dateRestrict format (e.g., d1, d5, w1, m3, y1)
 * @param {string} value - dateRestrict value to validate
 * @returns {boolean} True if valid format
 */
function isValidDateRestrict(value) {
  return /^[dwmy]\d+$/.test(value);
}

/**
 * Parses command line arguments
 * @param {string[]} args - Command line arguments
 * @returns {{query: string, num: number, start: number, dateRestrict: string|null, siteSearch: string|null, exactTerms: string|null, excludeTerms: string|null}} Parsed arguments
 */
function parseArgs(args) {
  let query = '';
  let num = DEFAULT_NUM_RESULTS;
  let start = DEFAULT_START_INDEX;
  let dateRestrict = null;
  let siteSearch = null;
  let exactTerms = null;
  let excludeTerms = null;

  for (const arg of args) {
    if (arg.startsWith('--num=')) {
      const value = parseInt(arg.slice(6), 10);
      if (!isNaN(value) && value >= 1 && value <= 10) {
        num = value;
      }
    } else if (arg.startsWith('--start=')) {
      const value = parseInt(arg.slice(8), 10);
      // Google API allows start from 1 to 91 (max 100 results total)
      if (!isNaN(value) && value >= 1 && value <= 91) {
        start = value;
      }
    } else if (arg.startsWith('--date=')) {
      const value = arg.slice(7);
      if (isValidDateRestrict(value)) {
        dateRestrict = value;
      }
    } else if (arg.startsWith('--site=')) {
      const value = arg.slice(7).trim();
      if (value) {
        siteSearch = value;
      }
    } else if (arg.startsWith('--exact=')) {
      const value = arg.slice(8).trim();
      if (value) {
        exactTerms = value;
      }
    } else if (arg.startsWith('--exclude=')) {
      const value = arg.slice(10).trim();
      if (value) {
        excludeTerms = value;
      }
    } else if (!arg.startsWith('--')) {
      query = arg;
    }
  }

  return { query: sanitizeInput(query), num, start, dateRestrict, siteSearch, exactTerms, excludeTerms };
}

/**
 * Constructs the API URL with parameters
 * @param {string} query - Search query
 * @param {string} apiKey - Google API key
 * @param {string} cx - Search engine ID
 * @param {number} num - Number of results
 * @param {number} start - Starting index for results (1-based)
 * @param {object} options - Optional advanced parameters
 * @param {string|null} options.dateRestrict - Restrict results by date (e.g., d1, w1, m1, y1)
 * @param {string|null} options.siteSearch - Restrict results to a specific site
 * @param {string|null} options.exactTerms - Include exact phrase in results
 * @param {string|null} options.excludeTerms - Exclude terms from results
 * @returns {string} Complete API URL
 */
function buildApiUrl(query, apiKey, cx, num, start = DEFAULT_START_INDEX, options = {}) {
  const params = new URLSearchParams({
    key: apiKey,
    cx: cx,
    q: query,
    num: num.toString(),
    start: start.toString(),
    fields: DEFAULT_FIELDS
  });

  // Add optional advanced parameters
  if (options.dateRestrict) {
    params.set('dateRestrict', options.dateRestrict);
  }
  if (options.siteSearch) {
    params.set('siteSearch', options.siteSearch);
  }
  if (options.exactTerms) {
    params.set('exactTerms', options.exactTerms);
  }
  if (options.excludeTerms) {
    params.set('excludeTerms', options.excludeTerms);
  }

  return `${API_ENDPOINT}?${params.toString()}`;
}

/**
 * Maps HTTP status codes to user-friendly error messages
 * @param {number} status - HTTP status code
 * @param {object} errorBody - Parsed error response body
 * @returns {string} User-friendly error message
 */
function getErrorMessage(status, errorBody) {
  const errorDetail = errorBody?.error?.message || '';

  switch (status) {
    case 400:
      return `Bad Request: Invalid parameters. ${errorDetail}`;
    case 401:
      return 'Unauthorized: Invalid API key. Please check your GOOGLE_API_KEY environment variable.';
    case 403:
      if (errorDetail.includes('quota')) {
        return 'Forbidden: API quota exceeded. Free tier allows 100 queries/day.';
      }
      return `Forbidden: Access denied. The API key may lack permission or the cx is invalid. ${errorDetail}`;
    case 429:
      return 'Too Many Requests: Rate limit exceeded. Please wait and try again.';
    case 500:
      return 'Server Error: Google API is experiencing issues. Please try again later.';
    case 503:
      return 'Service Unavailable: Google API is temporarily unavailable. Please try again later.';
    default:
      return `API Error (${status}): ${errorDetail || 'Unknown error occurred.'}`;
  }
}

/**
 * Formats search results as markdown
 * @param {string} query - Original search query
 * @param {object[]} items - Search result items
 * @param {number} start - Starting index for numbering (1-based)
 * @returns {string} Formatted markdown output
 */
function formatResults(query, items, start = DEFAULT_START_INDEX) {
  if (!items || items.length === 0) {
    return `## Search Results for: "${query}"\n\nNo results found.`;
  }

  let output = `## Search Results for: "${query}"`;
  if (start > 1) {
    output += ` (Results ${start}-${start + items.length - 1})`;
  }
  output += '\n\n';

  items.forEach((item, index) => {
    const title = item.title || 'Untitled';
    const link = item.link || '';
    const snippet = item.snippet || 'No description available.';

    output += `${start + index}. **${title}**\n`;
    output += `   ${link}\n`;
    output += `   ${snippet}\n\n`;
  });

  return output.trim();
}

/**
 * Main search function
 */
async function search() {
  // Parse command line arguments (skip node and script path)
  const args = process.argv.slice(2);
  const { query, num, start, dateRestrict, siteSearch, exactTerms, excludeTerms } = parseArgs(args);

  // Validate query
  if (!query) {
    console.error('Error: No search query provided.\n');
    console.error('Usage: node search.js "search query" [options]');
    console.error('\nOptions:');
    console.error('  --num=N         Number of results (1-10, default: 10)');
    console.error('  --start=N       Starting index for pagination (1-91, default: 1)');
    console.error('  --date=PERIOD   Restrict by date (d1=day, w1=week, m1=month, y1=year)');
    console.error('  --site=DOMAIN   Restrict to specific site (e.g., github.com)');
    console.error('  --exact=PHRASE  Require exact phrase in results');
    console.error('  --exclude=TERMS Exclude terms from results');
    process.exit(1);
  }

  // Get credentials from environment
  const apiKey = process.env.GOOGLE_API_KEY;
  const cx = process.env.GOOGLE_CX;

  // Validate credentials
  if (!apiKey) {
    console.error('Error: GOOGLE_API_KEY environment variable is not set.');
    console.error('\nTo set it:');
    console.error('  export GOOGLE_API_KEY="your-api-key-here"');
    console.error('\nTo obtain an API key:');
    console.error('  1. Go to https://console.cloud.google.com/');
    console.error('  2. Create a project and enable "Custom Search API"');
    console.error('  3. Generate an API key');
    process.exit(1);
  }

  if (!cx) {
    console.error('Error: GOOGLE_CX environment variable is not set.');
    console.error('\nTo set it:');
    console.error('  export GOOGLE_CX="your-search-engine-id"');
    console.error('\nTo obtain a Search Engine ID:');
    console.error('  1. Go to https://programmablesearchengine.google.com/');
    console.error('  2. Create a search engine');
    console.error('  3. Copy the Search Engine ID from the control panel');
    process.exit(1);
  }

  // Build API URL
  const url = buildApiUrl(query, apiKey, cx, num, start, {
    dateRestrict,
    siteSearch,
    exactTerms,
    excludeTerms
  });

  try {
    // Execute HTTP request
    const response = await fetch(url);

    // Handle non-OK responses
    if (!response.ok) {
      let errorBody = {};
      try {
        errorBody = await response.json();
      } catch {
        // Ignore JSON parse errors for error responses
      }
      const errorMessage = getErrorMessage(response.status, errorBody);
      console.error(`Error: ${errorMessage}`);
      process.exit(1);
    }

    // Parse successful response
    const data = await response.json();

    // Format and output results
    const output = formatResults(query, data.items, start);
    console.log(output);

  } catch (error) {
    // Handle network errors
    if (error.code === 'ENOTFOUND' || error.code === 'EAI_AGAIN') {
      console.error('Error: Network error. Please check your internet connection.');
    } else if (error.code === 'ETIMEDOUT' || error.code === 'ESOCKETTIMEDOUT') {
      console.error('Error: Request timed out. Please try again.');
    } else {
      console.error(`Error: ${error.message || 'An unexpected error occurred.'}`);
    }
    process.exit(1);
  }
}

// Export functions for testing
module.exports = {
  sanitizeInput,
  isValidDateRestrict,
  parseArgs,
  buildApiUrl,
  getErrorMessage,
  formatResults,
  search,
  // Constants for testing
  API_ENDPOINT,
  DEFAULT_FIELDS,
  DEFAULT_NUM_RESULTS,
  DEFAULT_START_INDEX
};

// Run the search if executed directly
if (require.main === module) {
  search();
}
