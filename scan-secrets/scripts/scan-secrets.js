#!/usr/bin/env node
const { execFileSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const USAGE = `Usage: scan-secrets.js [dir] [options]

Scan a directory for plaintext secrets. All values in the output are masked.

Options:
  --all            Turn off the false-positive filters of the heuristic rule
  --context=N      Show N masked lines around each finding (default 0)
  --no-gitleaks    Skip gitleaks even when it is installed
  --no-history     Skip the gitleaks scan of the git history
  --json           Print the report as JSON
  -h, --help       Show this help

Exit codes: 0 nothing found, 1 findings, 2 error.`;

const args = process.argv.slice(2);
if (args.includes('-h') || args.includes('--help')) {
  console.log(USAGE);
  process.exit(0);
}
const opt = (name) => args.includes(`--${name}`);
const contextArg = args.find((a) => a.startsWith('--context='));
const contextLines = contextArg ? Math.max(0, parseInt(contextArg.split('=')[1], 10) || 0) : 0;
const unknown = args.filter((a) => a.startsWith('-') && !/^--(all|no-gitleaks|no-history|json|context=\d+)$/.test(a));
if (unknown.length) {
  console.error(`Unknown option(s): ${unknown.join(', ')}\n\n${USAGE}`);
  process.exit(2);
}
const target = path.resolve(args.find((a) => !a.startsWith('-')) || '.');
if (!fs.existsSync(target) || !fs.statSync(target).isDirectory()) {
  console.error(`Not a directory: ${target}`);
  process.exit(2);
}

const rules = [
  { id: 'aws-access-key-id', re: /\b((?:AKIA|ASIA|AGPA|AIDA|AROA|ANPA|ANVA|AIPA)[A-Z0-9]{16})\b/g },
  { id: 'aws-secret-key', re: /aws_?secret_?(?:access_?)?key\W{0,5}[:=]\s*["']?([A-Za-z0-9/+=]{40})\b/gi },
  { id: 'private-key-block', re: /(-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY(?: BLOCK)?-----)/g },
  { id: 'github-token', re: /\b(gh[pousr]_[A-Za-z0-9]{36,})\b/g },
  { id: 'gitlab-token', re: /\b(glpat-[A-Za-z0-9_-]{20,})\b/g },
  { id: 'slack-token', re: /\b(xox[abprs]-[A-Za-z0-9-]{10,})\b/g },
  { id: 'slack-webhook', re: /(https:\/\/hooks\.slack\.com\/services\/[A-Za-z0-9/]+)/g },
  { id: 'google-api-key', re: /\b(AIza[0-9A-Za-z_-]{35})\b/g },
  { id: 'stripe-key', re: /\b((?:sk|rk)_live_[0-9A-Za-z]{20,})\b/g },
  { id: 'sendgrid-key', re: /\b(SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43})\b/g },
  { id: 'npm-token', re: /\b(npm_[A-Za-z0-9]{36})\b/g },
  { id: 'atlassian-token', re: /\b(ATATT[A-Za-z0-9_=-]{20,}|ATBB[A-Za-z0-9_=-]{20,}|ATCTT[A-Za-z0-9_=-]{20,})\b/g },
  { id: 'anthropic-key', re: /\b(sk-ant-[A-Za-z0-9_-]{20,})\b/g },
  { id: 'openai-key', re: /\b(sk-(?:proj-)?[A-Za-z0-9_-]{20,}T3BlbkFJ[A-Za-z0-9_-]{20,})\b/g },
  { id: 'jwt', re: /\b(eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})\b/g },
  { id: 'sonar-token', re: /sonar\.(?:login|token)\s*=\s*["']?((?:sq[apu]_)?[a-f0-9]{40})\b/gi },
  { id: 'url-with-credentials', re: /\b[a-z][a-z0-9+.-]*:\/\/[^\s:@\/"']+:([^\s:@\/"'{}$]{3,})@[^\s"']+/gi },
  { id: 'basic-auth-cli', re: /(?:-u|--user|--password|-p)\s+["']?[^\s:"'$]+:([^\s"'$]{6,})/g },
  { id: 'docker-auth', re: /"auth"\s*:\s*"([A-Za-z0-9+/=]{16,})"/g },
  {
    id: 'generic-secret-assignment',
    re: /\b[\w.-]*(?:password|passwd|pwd|secret|token|api[_-]?key|apikey|access[_-]?key|private[_-]?key|client[_-]?secret|auth)[\w.-]*["']?\s*[:=]\s*(?:"([^"\s]{8,})"|'([^'\s]{8,})'|["']?([^\s"'#,}\]]{8,}))/gi,
    heuristic: true,
  },
];

const placeholder = /^(\$|\{\{|\$\{|%\(|<|!|\[|\(|lookup|vault_|env\.|secrets\.|var\.|local\.|data\.|module\.|aws_|resolve:|arn:|ssm:|true$|false$|null$|none$|changeme|change_me|example|xxx|your[_-]|dummy|placeholder|redacted|\*+$|required$|optional$|string$|ref$)/i;

const skipExt = new Set(['.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.svg', '.zip', '.gz', '.tgz', '.jar', '.woff', '.woff2', '.ttf', '.eot', '.pdf', '.lock', '.map']);
const skipDirs = new Set(['.git', 'node_modules', 'vendor', 'dist', 'build', '.venv', 'venv', '__pycache__', '.terraform', '.next', 'coverage']);
const maxFileBytes = 5 * 1024 * 1024;
const maxLineLength = 2000;

function entropy(s) {
  const freq = {};
  for (const c of s) freq[c] = (freq[c] || 0) + 1;
  return Object.values(freq).reduce((h, n) => h - (n / s.length) * Math.log2(n / s.length), 0);
}

function redact(s) {
  if (s.startsWith('-----BEGIN')) return s;
  return s.length <= 8 ? '*'.repeat(s.length) : `${s.slice(0, 4)}…(${s.length} chars)`;
}

function captured(m) {
  return m.slice(1).find((g) => g !== undefined);
}

function maskLine(line, values) {
  const all = new Set(values);
  for (const rule of rules) {
    for (const m of line.matchAll(new RegExp(rule.re.source, rule.re.flags))) {
      const v = captured(m);
      if (!v.startsWith('-----BEGIN')) all.add(v);
    }
  }
  let out = line;
  for (const v of [...all].sort((a, b) => b.length - a.length)) out = out.split(v).join(redact(v));
  return out.replace(/[A-Za-z0-9+/=_-]{14,}/g, (m) => (/^[a-z_/.-]+$/.test(m) && !/\d/.test(m) ? m : redact(m)));
}

function looksLikeRealSecret(value, quoted) {
  if (placeholder.test(value)) return false;
  if (/^[\w.-]+\.(ya?ml|json|j2|sh|py|txt|pem|key|conf)$/i.test(value)) return false;
  if (/^[\w-]+\/[\w./-]+$/.test(value) && !/[A-Z0-9+=]{20,}/.test(value)) return false;
  if (/^(\/|\\\$|\.\*|\.\/|~)/.test(value)) return false;
  if (quoted && /[A-Za-z0-9]/.test(value) && /[!@#%^&*?~+=]/.test(value) && !/[{}()\s]/.test(value)) return true;
  if (/^[a-z_]+$/i.test(value)) return false;
  if (/^[A-Za-z_]\w*(\.\w+|\[|\()/.test(value) && !/[A-Za-z0-9+/]{30,}/.test(value)) return false;
  if (/^[A-Za-z0-9]+$/.test(value) && (value.length < 16 || !/\d/.test(value) || !/[A-Za-z]/.test(value))) return false;
  return entropy(value) >= 3.0;
}

function isGitRepo(dir) {
  const r = spawnSync('git', ['-C', dir, 'rev-parse', '--is-inside-work-tree'], { encoding: 'utf8' });
  return r.status === 0 && r.stdout.trim() === 'true';
}

function walk(dir, base, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!skipDirs.has(entry.name)) walk(path.join(dir, entry.name), base, out);
    } else if (entry.isFile()) {
      out.push(path.relative(base, path.join(dir, entry.name)));
    }
  }
  return out;
}

function listFiles(dir, git) {
  if (!git) return walk(dir, dir, []);
  return execFileSync('git', ['-C', dir, 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], {
    encoding: 'utf8',
    maxBuffer: 256 * 1024 * 1024,
  })
    .split('\0')
    .filter(Boolean);
}

function builtinScan(dir, files) {
  const findings = [];
  let vaultFiles = 0;
  let scanned = 0;
  for (const rel of files) {
    if (skipExt.has(path.extname(rel).toLowerCase())) continue;
    let text;
    try {
      const abs = path.join(dir, rel);
      const stat = fs.lstatSync(abs);
      if (!stat.isFile() || stat.size > maxFileBytes) continue;
      const buf = fs.readFileSync(abs);
      if (buf.includes(0)) continue;
      text = buf.toString('utf8');
    } catch {
      continue;
    }
    scanned++;
    if (text.startsWith('$ANSIBLE_VAULT')) {
      vaultFiles++;
      continue;
    }
    const lines = text.split(/\r?\n/);
    lines.forEach((line, i) => {
      if (line.length > maxLineLength) return;
      if (/\$ANSIBLE_VAULT|!vault\s*\|/.test(line)) return;
      const caught = new Set();
      for (const rule of rules) {
        rule.re.lastIndex = 0;
        let m;
        while ((m = rule.re.exec(line))) {
          const value = captured(m);
          if (rule.heuristic) {
            if ([...caught].some((c) => c.includes(value) || value.includes(c))) continue;
            const quoted = m[1] !== undefined || m[2] !== undefined;
            if (!opt('all') && !looksLikeRealSecret(value, quoted)) continue;
          } else {
            caught.add(value);
          }
          const finding = { rule: rule.id, file: rel, line: i + 1, value: redact(value), heuristic: !!rule.heuristic };
          if (contextLines) {
            const from = Math.max(0, i - contextLines);
            finding.context = lines
              .slice(from, i + contextLines + 1)
              .map((l, j) => `${String(from + j + 1).padStart(5)}${from + j === i ? '>' : ' '} ${l.length > maxLineLength ? '[long line skipped]' : maskLine(l, [value])}`);
          }
          findings.push(finding);
        }
      }
    });
  }
  return { findings, vaultFiles, scanned };
}

function gitleaksVersion() {
  const r = spawnSync('gitleaks', ['version'], { encoding: 'utf8' });
  return r.error ? null : r.stdout.trim();
}

function runGitleaks(mode, dir) {
  const r = spawnSync('gitleaks', [mode, dir, '--redact', '--no-banner', '--log-level', 'error', '--report-format', 'json', '--report-path', '-'], {
    encoding: 'utf8',
    maxBuffer: 256 * 1024 * 1024,
  });
  try {
    const report = JSON.parse(r.stdout || '[]');
    return {
      findings: report.map((x) => ({
        rule: x.RuleID,
        file: x.File,
        line: x.StartLine,
        commit: x.Commit ? x.Commit.slice(0, 8) : undefined,
        date: x.Date || undefined,
      })),
    };
  } catch {
    return { error: (r.stderr || r.error?.message || `exit code ${r.status}`).trim().split('\n').slice(-3).join('\n') };
  }
}

function groupByRuleAndFile(findings) {
  const groups = new Map();
  for (const f of findings) {
    const key = `${f.rule}\t${f.file}`;
    const g = groups.get(key) || { rule: f.rule, file: f.file, count: 0, lines: new Set(), commits: new Set() };
    g.count++;
    if (f.line) g.lines.add(f.line);
    if (f.commit) g.commits.add(f.commit);
    groups.set(key, g);
  }
  return [...groups.values()]
    .sort((a, b) => a.file.localeCompare(b.file) || a.rule.localeCompare(b.rule))
    .map((g) => ({ ...g, lines: [...g.lines].sort((a, b) => a - b), commits: [...g.commits] }));
}

const git = isGitRepo(target);
const files = listFiles(target, git);
const builtin = builtinScan(target, files);

const report = {
  target,
  gitRepo: git,
  filesListed: files.length,
  filesScanned: builtin.scanned,
  ansibleVaultFiles: builtin.vaultFiles,
  builtin: {
    highConfidence: builtin.findings.filter((f) => !f.heuristic),
    heuristic: builtin.findings.filter((f) => f.heuristic),
  },
  gitleaks: { status: 'skipped' },
};

if (!opt('no-gitleaks')) {
  const version = gitleaksVersion();
  if (!version) {
    report.gitleaks = { status: 'not-installed', install: 'brew install gitleaks, or a release from https://github.com/gitleaks/gitleaks/releases' };
  } else {
    report.gitleaks = { status: 'ran', version, dir: runGitleaks('dir', target) };
    if (!git) report.gitleaks.history = { skipped: 'not a git repository' };
    else if (opt('no-history')) report.gitleaks.history = { skipped: '--no-history' };
    else report.gitleaks.history = runGitleaks('git', target);
  }
}

const totalFindings =
  report.builtin.highConfidence.length +
  report.builtin.heuristic.length +
  (report.gitleaks.dir?.findings?.length || 0) +
  (report.gitleaks.history?.findings?.length || 0);
const gitleaksError = report.gitleaks.dir?.error || report.gitleaks.history?.error;

if (opt('json')) {
  console.log(JSON.stringify(report, null, 2));
} else {
  const out = [];
  const section = (title, list, fmt) => {
    out.push(`\n=== ${title} (${list.length}) ===`);
    for (const item of list) out.push(fmt(item));
  };
  const fmtBuiltin = (f) => [`${f.file}:${f.line}  [${f.rule}]  ${f.value}`, ...(f.context || []), ...(f.context ? [''] : [])].join('\n');
  const fmtGroup = (g) =>
    `${g.file}${g.lines.length ? `:${g.lines.slice(0, 5).join(',')}${g.lines.length > 5 ? ',…' : ''}` : ''}  [${g.rule}]` +
    (g.commits.length ? `  ${g.commits.length} commit(s): ${g.commits.slice(0, 3).join(' ')}${g.commits.length > 3 ? ' …' : ''}` : '');

  out.push(`Target: ${target}${git ? ' (git repository: tracked + untracked, non-ignored files)' : ' (not a git repository: directory walk)'}`);
  out.push(`Files scanned by built-in rules: ${report.filesScanned} of ${report.filesListed} listed`);
  if (report.ansibleVaultFiles) out.push(`Ansible Vault encrypted files skipped: ${report.ansibleVaultFiles}`);
  section('Built-in: high-confidence matches (known token formats)', report.builtin.highConfidence, fmtBuiltin);
  section('Built-in: possible hardcoded secrets (heuristic, review manually)', report.builtin.heuristic, fmtBuiltin);

  const gl = report.gitleaks;
  if (gl.status === 'not-installed') {
    out.push(`\n=== gitleaks: not installed. Install with ${gl.install} ===`);
  } else if (gl.status === 'skipped') {
    out.push('\n=== gitleaks: skipped (--no-gitleaks) ===');
  } else {
    out.push(`\n--- gitleaks ${gl.version} ---`);
    if (gl.dir.error) out.push(`\n=== gitleaks dir: failed ===\n${gl.dir.error}`);
    else section('gitleaks dir: files on disk, including gitignored files (grouped)', groupByRuleAndFile(gl.dir.findings), fmtGroup);
    if (gl.history.skipped) out.push(`\n=== gitleaks git history: skipped (${gl.history.skipped}) ===`);
    else if (gl.history.error) out.push(`\n=== gitleaks git history: failed ===\n${gl.history.error}`);
    else section('gitleaks git: full git history (grouped)', groupByRuleAndFile(gl.history.findings), fmtGroup);
  }
  console.log(out.join('\n'));
}

process.exitCode = gitleaksError ? 2 : totalFindings ? 1 : 0;
