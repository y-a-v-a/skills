// Fixture tests for scripts/scan-secrets.js.  Run: node --test scan-secrets/tests
//
// Fake secrets are assembled at runtime from fragments, so this file never
// contains a complete token pattern: no scanner (this one, gitleaks, GitHub
// push protection) flags the repository because of its own tests.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

// SCAN_SECRETS_SCRIPT points the suite at another version (e.g. to show a
// regression test fails on the old code).
const SCRIPT = process.env.SCAN_SECRETS_SCRIPT || path.join(__dirname, '..', 'scripts', 'scan-secrets.js');
const j = (...parts) => parts.join('');

// Planted secrets: rule id the scanner must report, and the raw value that
// must never appear unmasked in any output mode.
const SECRETS = {
  aws: j('AKIA', 'Q7RT', 'ZX3M', 'P9LK', 'W2NB'),
  github: j('gh', 'p_', 'a1B2c3D4e5F6'.repeat(3)),
  generic: j('Tr0ub4', 'dor&3xyz'),
  npmrc: j('a8F3kQ9z', 'L2mX7pW4'),
  urlPass: j('s3cr3t', 'Pa55w0rd'),
  lockToken: j('npm', 'Tok', '9x8Y7z6W5v'),
};

const FILES = {
  // must be found
  'config/aws.env': `AWS_ACCESS_KEY_ID=${SECRETS.aws}\n`,
  'scripts/release.sh': `export GH_TOKEN=${SECRETS.github}\n`,
  'app/settings.py': `DB_PASSWORD = "${SECRETS.generic}"\n`,
  '.npmrc': `//registry.example.com/:_authToken=${SECRETS.npmrc}\n`,
  'deploy.txt': `git clone https://deploy:${SECRETS.urlPass}@git.example.com/app.git\n`,
  'yarn.lock': `"pkg@^1.0.0":\n  resolved "https://ci:${SECRETS.lockToken}@npm.example.com/pkg/-/pkg-1.0.0.tgz"\n`,
  'keys/id_rsa': j('-----BEGIN ', 'RSA PRIVATE KEY-----\n', 'MIIEpAIBAAKCAQEA7q2'.repeat(3), '\n-----END RSA PRIVATE KEY-----\n'),
  // must NOT be found (known false positives)
  'skill/SKILL.md': '---\nname: x\nmetadata:\n  author: Jane Doe\n  author-url: https://example.com\n---\n',
  'web/meta.js': 'const authorUrl = "https://example.com/about-the-author";\nconst authority = "login.example.com";\n',
  'oidc.yaml': 'token_endpoint: "https://auth.example.com/oauth2/token"\nauthorization_endpoint: https://auth.example.com/authorize\n',
  'compose.yaml': 'environment:\n  password: "${DB_PASSWORD}"\n  api_key: "{{ vault_api_key }}"\n',
  'app/env.py': 'api_key = os.environ["API_KEY"]\n',
};

function fixtureDir() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'scan-secrets-test-'));
  for (const [rel, body] of Object.entries(FILES)) {
    fs.mkdirSync(path.join(dir, path.dirname(rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), body);
  }
  return dir;
}

function scan(dir, ...flags) {
  const r = spawnSync(process.execPath, [SCRIPT, dir, '--no-gitleaks', ...flags], { encoding: 'utf8' });
  return r;
}

const dir = fixtureDir();
process.on('exit', () => fs.rmSync(dir, { recursive: true, force: true }));

test('finds every planted secret, in the file it was planted in', () => {
  const r = scan(dir, '--json');
  assert.strictEqual(r.status, 1, 'exit code 1 means findings');
  const report = JSON.parse(r.stdout);
  const all = [...report.builtin.highConfidence, ...report.builtin.heuristic];
  const found = (file, rule) => all.some((f) => f.file === file && (!rule || f.rule === rule));

  assert.ok(found('config/aws.env', 'aws-access-key-id'), 'AWS key id');
  assert.ok(found('scripts/release.sh', 'github-token'), 'GitHub token');
  assert.ok(found('app/settings.py', 'generic-secret-assignment'), 'hardcoded password');
  assert.ok(found('.npmrc', 'generic-secret-assignment'), '_authToken in .npmrc');
  assert.ok(found('deploy.txt', 'url-with-credentials'), 'credentials in a URL');
  assert.ok(found('yarn.lock', 'url-with-credentials'), 'lockfiles are scanned');
  assert.ok(found('keys/id_rsa', 'private-key-block'), 'private key block');
});

test('reports nothing for known false positives', () => {
  const report = JSON.parse(scan(dir, '--json').stdout);
  const all = [...report.builtin.highConfidence, ...report.builtin.heuristic];
  for (const file of ['skill/SKILL.md', 'web/meta.js', 'oidc.yaml', 'compose.yaml', 'app/env.py']) {
    const hits = all.filter((f) => f.file === file);
    assert.deepStrictEqual(hits, [], `false positive in ${file}: ${JSON.stringify(hits)}`);
  }
});

test('never prints a secret value unmasked, in any output mode', () => {
  for (const flags of [[], ['--context=2'], ['--json'], ['--json', '--context=2'], ['--all', '--context=3']]) {
    const out = scan(dir, ...flags).stdout;
    for (const [name, value] of Object.entries(SECRETS)) {
      assert.ok(!out.includes(value), `${name} leaked unmasked with ${flags.join(' ') || 'no flags'}`);
    }
  }
});

test('exits 0 on a clean directory', () => {
  const clean = fs.mkdtempSync(path.join(os.tmpdir(), 'scan-secrets-clean-'));
  fs.writeFileSync(path.join(clean, 'README.md'), '# Nothing to see\n\nauthor: Jane Doe\n');
  const r = scan(clean);
  fs.rmSync(clean, { recursive: true, force: true });
  assert.strictEqual(r.status, 0, r.stdout + r.stderr);
});
