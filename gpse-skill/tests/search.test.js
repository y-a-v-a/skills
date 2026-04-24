#!/usr/bin/env node

/**
 * Unit tests for Google Programmable Search Engine Script
 *
 * Run with: node --test tests/search.test.js
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');

const {
  sanitizeInput,
  isValidDateRestrict,
  parseArgs,
  buildApiUrl,
  getErrorMessage,
  formatResults,
  API_ENDPOINT,
  DEFAULT_FIELDS,
  DEFAULT_NUM_RESULTS,
  DEFAULT_START_INDEX
} = require('../skill/scripts/search.js');

describe('sanitizeInput', () => {
  it('should return empty string for non-string input', () => {
    assert.strictEqual(sanitizeInput(null), '');
    assert.strictEqual(sanitizeInput(undefined), '');
    assert.strictEqual(sanitizeInput(123), '');
    assert.strictEqual(sanitizeInput({}), '');
  });

  it('should trim whitespace from strings', () => {
    assert.strictEqual(sanitizeInput('  hello  '), 'hello');
    assert.strictEqual(sanitizeInput('\thello\n'), 'hello');
  });

  it('should remove control characters', () => {
    assert.strictEqual(sanitizeInput('hello\x00world'), 'helloworld');
    assert.strictEqual(sanitizeInput('\x01\x02\x03test'), 'test');
  });

  it('should preserve normal characters', () => {
    assert.strictEqual(sanitizeInput('Hello World!'), 'Hello World!');
    assert.strictEqual(sanitizeInput('search query 2024'), 'search query 2024');
  });

  it('should preserve unicode characters', () => {
    assert.strictEqual(sanitizeInput('日本語 test'), '日本語 test');
    assert.strictEqual(sanitizeInput('café résumé'), 'café résumé');
  });
});

describe('isValidDateRestrict', () => {
  it('should accept valid day format', () => {
    assert.strictEqual(isValidDateRestrict('d1'), true);
    assert.strictEqual(isValidDateRestrict('d5'), true);
    assert.strictEqual(isValidDateRestrict('d30'), true);
  });

  it('should accept valid week format', () => {
    assert.strictEqual(isValidDateRestrict('w1'), true);
    assert.strictEqual(isValidDateRestrict('w4'), true);
  });

  it('should accept valid month format', () => {
    assert.strictEqual(isValidDateRestrict('m1'), true);
    assert.strictEqual(isValidDateRestrict('m12'), true);
  });

  it('should accept valid year format', () => {
    assert.strictEqual(isValidDateRestrict('y1'), true);
    assert.strictEqual(isValidDateRestrict('y5'), true);
  });

  it('should reject invalid formats', () => {
    assert.strictEqual(isValidDateRestrict(''), false);
    assert.strictEqual(isValidDateRestrict('d'), false);
    assert.strictEqual(isValidDateRestrict('1d'), false);
    assert.strictEqual(isValidDateRestrict('x1'), false);
    assert.strictEqual(isValidDateRestrict('day1'), false);
    assert.strictEqual(isValidDateRestrict('1'), false);
  });
});

describe('parseArgs', () => {
  it('should parse query from positional argument', () => {
    const result = parseArgs(['machine learning']);
    assert.strictEqual(result.query, 'machine learning');
    assert.strictEqual(result.num, DEFAULT_NUM_RESULTS);
  });

  it('should parse --num flag', () => {
    const result = parseArgs(['test query', '--num=5']);
    assert.strictEqual(result.query, 'test query');
    assert.strictEqual(result.num, 5);
  });

  it('should handle --num flag before query', () => {
    const result = parseArgs(['--num=3', 'my query']);
    assert.strictEqual(result.query, 'my query');
    assert.strictEqual(result.num, 3);
  });

  it('should limit num to valid range (1-10)', () => {
    assert.strictEqual(parseArgs(['test', '--num=0']).num, DEFAULT_NUM_RESULTS);
    assert.strictEqual(parseArgs(['test', '--num=11']).num, DEFAULT_NUM_RESULTS);
    assert.strictEqual(parseArgs(['test', '--num=-1']).num, DEFAULT_NUM_RESULTS);
    assert.strictEqual(parseArgs(['test', '--num=abc']).num, DEFAULT_NUM_RESULTS);
  });

  it('should return empty query when no positional args', () => {
    const result = parseArgs(['--num=5']);
    assert.strictEqual(result.query, '');
  });

  it('should sanitize query input', () => {
    const result = parseArgs(['  test\x00query  ']);
    assert.strictEqual(result.query, 'testquery');
  });

  it('should parse --start flag', () => {
    const result = parseArgs(['test query', '--start=11']);
    assert.strictEqual(result.query, 'test query');
    assert.strictEqual(result.start, 11);
  });

  it('should handle --start flag before query', () => {
    const result = parseArgs(['--start=21', 'my query']);
    assert.strictEqual(result.query, 'my query');
    assert.strictEqual(result.start, 21);
  });

  it('should limit start to valid range (1-91)', () => {
    assert.strictEqual(parseArgs(['test', '--start=0']).start, DEFAULT_START_INDEX);
    assert.strictEqual(parseArgs(['test', '--start=92']).start, DEFAULT_START_INDEX);
    assert.strictEqual(parseArgs(['test', '--start=-1']).start, DEFAULT_START_INDEX);
    assert.strictEqual(parseArgs(['test', '--start=abc']).start, DEFAULT_START_INDEX);
  });

  it('should return default start when not specified', () => {
    const result = parseArgs(['test query']);
    assert.strictEqual(result.start, DEFAULT_START_INDEX);
  });

  it('should parse both --num and --start flags', () => {
    const result = parseArgs(['query', '--num=5', '--start=11']);
    assert.strictEqual(result.query, 'query');
    assert.strictEqual(result.num, 5);
    assert.strictEqual(result.start, 11);
  });

  it('should parse --date flag with valid format', () => {
    const result = parseArgs(['test', '--date=d7']);
    assert.strictEqual(result.dateRestrict, 'd7');
  });

  it('should ignore --date flag with invalid format', () => {
    const result = parseArgs(['test', '--date=invalid']);
    assert.strictEqual(result.dateRestrict, null);
  });

  it('should parse --site flag', () => {
    const result = parseArgs(['test', '--site=github.com']);
    assert.strictEqual(result.siteSearch, 'github.com');
  });

  it('should ignore empty --site flag', () => {
    const result = parseArgs(['test', '--site=']);
    assert.strictEqual(result.siteSearch, null);
  });

  it('should parse --exact flag', () => {
    const result = parseArgs(['test', '--exact=machine learning']);
    assert.strictEqual(result.exactTerms, 'machine learning');
  });

  it('should ignore empty --exact flag', () => {
    const result = parseArgs(['test', '--exact=']);
    assert.strictEqual(result.exactTerms, null);
  });

  it('should parse --exclude flag', () => {
    const result = parseArgs(['test', '--exclude=spam ads']);
    assert.strictEqual(result.excludeTerms, 'spam ads');
  });

  it('should ignore empty --exclude flag', () => {
    const result = parseArgs(['test', '--exclude=']);
    assert.strictEqual(result.excludeTerms, null);
  });

  it('should parse all advanced flags together', () => {
    const result = parseArgs([
      'query',
      '--num=5',
      '--start=11',
      '--date=m1',
      '--site=example.com',
      '--exact=important',
      '--exclude=junk'
    ]);
    assert.strictEqual(result.query, 'query');
    assert.strictEqual(result.num, 5);
    assert.strictEqual(result.start, 11);
    assert.strictEqual(result.dateRestrict, 'm1');
    assert.strictEqual(result.siteSearch, 'example.com');
    assert.strictEqual(result.exactTerms, 'important');
    assert.strictEqual(result.excludeTerms, 'junk');
  });

  it('should return null for advanced params when not specified', () => {
    const result = parseArgs(['test query']);
    assert.strictEqual(result.dateRestrict, null);
    assert.strictEqual(result.siteSearch, null);
    assert.strictEqual(result.exactTerms, null);
    assert.strictEqual(result.excludeTerms, null);
  });
});

describe('buildApiUrl', () => {
  it('should build correct API URL with all parameters', () => {
    const url = buildApiUrl('test query', 'API_KEY', 'CX_ID', 10);

    assert.ok(url.startsWith(API_ENDPOINT));
    assert.ok(url.includes('key=API_KEY'));
    assert.ok(url.includes('cx=CX_ID'));
    assert.ok(url.includes('q=test+query') || url.includes('q=test%20query'));
    assert.ok(url.includes('num=10'));
    // URLSearchParams encodes parentheses and commas in the fields value
    assert.ok(url.includes('fields='));
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('fields'), DEFAULT_FIELDS);
  });

  it('should properly encode special characters in query', () => {
    const url = buildApiUrl('hello & world', 'key', 'cx', 5);
    assert.ok(url.includes('q=hello+%26+world') || url.includes('q=hello%20%26%20world'));
  });

  it('should use default fields parameter', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10);
    assert.ok(url.includes('fields='));
  });

  it('should include start parameter when provided', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 11);
    assert.ok(url.includes('start=11'));
  });

  it('should use default start when not provided', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10);
    assert.ok(url.includes('start=1'));
  });

  it('should include custom start index for pagination', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 21);
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('start'), '21');
  });

  it('should include dateRestrict when provided', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 1, { dateRestrict: 'd7' });
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('dateRestrict'), 'd7');
  });

  it('should include siteSearch when provided', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 1, { siteSearch: 'github.com' });
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('siteSearch'), 'github.com');
  });

  it('should include exactTerms when provided', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 1, { exactTerms: 'machine learning' });
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('exactTerms'), 'machine learning');
  });

  it('should include excludeTerms when provided', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 1, { excludeTerms: 'spam' });
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('excludeTerms'), 'spam');
  });

  it('should include all advanced options when provided', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 1, {
      dateRestrict: 'm1',
      siteSearch: 'example.com',
      exactTerms: 'important phrase',
      excludeTerms: 'junk spam'
    });
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('dateRestrict'), 'm1');
    assert.strictEqual(params.get('siteSearch'), 'example.com');
    assert.strictEqual(params.get('exactTerms'), 'important phrase');
    assert.strictEqual(params.get('excludeTerms'), 'junk spam');
  });

  it('should not include advanced options when null or undefined', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 1, {
      dateRestrict: null,
      siteSearch: undefined
    });
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('dateRestrict'), null);
    assert.strictEqual(params.get('siteSearch'), null);
  });

  it('should work with empty options object', () => {
    const url = buildApiUrl('test', 'key', 'cx', 10, 1, {});
    const params = new URLSearchParams(url.split('?')[1]);
    assert.strictEqual(params.get('dateRestrict'), null);
    assert.strictEqual(params.get('siteSearch'), null);
    assert.strictEqual(params.get('exactTerms'), null);
    assert.strictEqual(params.get('excludeTerms'), null);
  });
});

describe('getErrorMessage', () => {
  it('should return correct message for 400 status', () => {
    const msg = getErrorMessage(400, { error: { message: 'Bad param' } });
    assert.ok(msg.includes('Bad Request'));
    assert.ok(msg.includes('Bad param'));
  });

  it('should return correct message for 401 status', () => {
    const msg = getErrorMessage(401, {});
    assert.ok(msg.includes('Unauthorized'));
    assert.ok(msg.includes('Invalid API key'));
    assert.ok(msg.includes('GOOGLE_API_KEY'));
  });

  it('should return quota exceeded message for 403 with quota error', () => {
    const msg = getErrorMessage(403, { error: { message: 'quota exceeded' } });
    assert.ok(msg.includes('Forbidden'));
    assert.ok(msg.includes('quota'));
    assert.ok(msg.includes('100 queries/day'));
  });

  it('should return generic 403 message for non-quota errors', () => {
    const msg = getErrorMessage(403, { error: { message: 'Access denied' } });
    assert.ok(msg.includes('Forbidden'));
    assert.ok(msg.includes('Access denied'));
  });

  it('should return correct message for 429 status', () => {
    const msg = getErrorMessage(429, {});
    assert.ok(msg.includes('Too Many Requests'));
    assert.ok(msg.includes('Rate limit'));
  });

  it('should return correct message for 500 status', () => {
    const msg = getErrorMessage(500, {});
    assert.ok(msg.includes('Server Error'));
    assert.ok(msg.includes('Google API'));
  });

  it('should return correct message for 503 status', () => {
    const msg = getErrorMessage(503, {});
    assert.ok(msg.includes('Service Unavailable'));
  });

  it('should return generic error for unknown status codes', () => {
    const msg = getErrorMessage(418, { error: { message: "I'm a teapot" } });
    assert.ok(msg.includes('API Error (418)'));
    assert.ok(msg.includes("I'm a teapot"));
  });

  it('should handle missing error body gracefully', () => {
    const msg = getErrorMessage(500, null);
    assert.ok(msg.includes('Server Error'));
  });
});

describe('formatResults', () => {
  it('should format empty results', () => {
    const output = formatResults('test', []);
    assert.ok(output.includes('Search Results for: "test"'));
    assert.ok(output.includes('No results found'));
  });

  it('should format null items as no results', () => {
    const output = formatResults('test', null);
    assert.ok(output.includes('No results found'));
  });

  it('should format single result correctly', () => {
    const items = [{
      title: 'Test Title',
      link: 'https://example.com',
      snippet: 'This is a test snippet.'
    }];
    const output = formatResults('query', items);

    assert.ok(output.includes('Search Results for: "query"'));
    assert.ok(output.includes('1. **Test Title**'));
    assert.ok(output.includes('https://example.com'));
    assert.ok(output.includes('This is a test snippet.'));
  });

  it('should format multiple results with numbering', () => {
    const items = [
      { title: 'First', link: 'https://first.com', snippet: 'First desc' },
      { title: 'Second', link: 'https://second.com', snippet: 'Second desc' },
      { title: 'Third', link: 'https://third.com', snippet: 'Third desc' }
    ];
    const output = formatResults('test', items);

    assert.ok(output.includes('1. **First**'));
    assert.ok(output.includes('2. **Second**'));
    assert.ok(output.includes('3. **Third**'));
  });

  it('should handle missing fields with defaults', () => {
    const items = [{}];
    const output = formatResults('test', items);

    assert.ok(output.includes('**Untitled**'));
    assert.ok(output.includes('No description available'));
  });

  it('should handle partially filled items', () => {
    const items = [{ title: 'Only Title' }];
    const output = formatResults('test', items);

    assert.ok(output.includes('**Only Title**'));
    assert.ok(output.includes('No description available'));
  });

  it('should use start index for numbering when provided', () => {
    const items = [
      { title: 'First', link: 'https://first.com', snippet: 'First desc' },
      { title: 'Second', link: 'https://second.com', snippet: 'Second desc' }
    ];
    const output = formatResults('test', items, 11);

    assert.ok(output.includes('11. **First**'));
    assert.ok(output.includes('12. **Second**'));
  });

  it('should show result range in header when start > 1', () => {
    const items = [
      { title: 'Result', link: 'https://example.com', snippet: 'Desc' }
    ];
    const output = formatResults('query', items, 11);

    assert.ok(output.includes('(Results 11-11)'));
  });

  it('should show correct result range for multiple items', () => {
    const items = [
      { title: 'A', link: 'https://a.com', snippet: 'A' },
      { title: 'B', link: 'https://b.com', snippet: 'B' },
      { title: 'C', link: 'https://c.com', snippet: 'C' }
    ];
    const output = formatResults('query', items, 21);

    assert.ok(output.includes('(Results 21-23)'));
    assert.ok(output.includes('21. **A**'));
    assert.ok(output.includes('22. **B**'));
    assert.ok(output.includes('23. **C**'));
  });

  it('should not show result range when start is 1', () => {
    const items = [{ title: 'Result', link: 'https://example.com', snippet: 'Desc' }];
    const output = formatResults('query', items, 1);

    assert.ok(!output.includes('(Results'));
  });

  it('should use default start index when not specified', () => {
    const items = [{ title: 'Result', link: 'https://example.com', snippet: 'Desc' }];
    const output = formatResults('query', items);

    assert.ok(output.includes('1. **Result**'));
    assert.ok(!output.includes('(Results'));
  });
});

describe('constants', () => {
  it('should have correct API endpoint', () => {
    assert.strictEqual(API_ENDPOINT, 'https://www.googleapis.com/customsearch/v1');
  });

  it('should have correct default fields', () => {
    assert.strictEqual(DEFAULT_FIELDS, 'kind,items(title,link,snippet)');
  });

  it('should have correct default number of results', () => {
    assert.strictEqual(DEFAULT_NUM_RESULTS, 10);
  });

  it('should have correct default start index', () => {
    assert.strictEqual(DEFAULT_START_INDEX, 1);
  });
});
