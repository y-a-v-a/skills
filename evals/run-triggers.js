#!/usr/bin/env node
// run-triggers.js — check that skill descriptions route prompts correctly.
//
// For each case in triggers.json, runs a headless Claude Code session in a
// scratch project whose .claude/skills/ links every skill in this repo, and
// records which skill(s) the model loads with the Skill tool. Only routing is
// tested: every other tool is disallowed and the session stops after one turn,
// so nothing a skill describes is actually carried out.
//
// Usage: node evals/run-triggers.js [--skill <name>] [--concurrency N] [--model M] [--json out.json]
// Exit:  0 all cases pass, 1 a case failed, 2 setup error.
//
// Caveats:
// - A user-level skill (~/.claude/skills/<name>) wins over a project skill of
//   the same name, so stale installed copies are what gets tested. Run
//   ./link-skill.sh --check first.
// - Routing is probabilistic. A case that fails once is worth re-running
//   (--skill <name>) before rewriting a description.
// - Each case is a real model call.
const { spawn, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const REPO = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : dflt;
};
const ONLY = opt('skill');
const CONCURRENCY = Math.max(1, parseInt(opt('concurrency', '4'), 10) || 4);
const MODEL = opt('model');
const JSON_OUT = opt('json');
const TIMEOUT_MS = 240_000;

if (spawnSync('claude', ['--version'], { encoding: 'utf8' }).status !== 0) {
  console.error('claude CLI not found on PATH');
  process.exit(2);
}

// --- discover skills (same rules as link-skill.sh) --------------------------
function frontmatterName(file) {
  const m = fs.readFileSync(file, 'utf8').match(/^---\n([\s\S]*?)\n---/);
  const n = m && m[1].match(/^name:\s*["']?([^"'\n]+?)["']?\s*$/m);
  return n ? n[1] : path.basename(path.dirname(file));
}
function findSkills(dir, out = {}) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (['.git', 'node_modules', '.claude', 'evals'].includes(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) findSkills(p, out);
    else if (e.name === 'SKILL.md') out[frontmatterName(p)] = dir;
  }
  return out;
}
const skills = findSkills(REPO);

// --- scratch project ---------------------------------------------------------
const project = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-triggers-'));
fs.mkdirSync(path.join(project, '.claude', 'skills'), { recursive: true });
for (const [name, dir] of Object.entries(skills)) {
  fs.symlinkSync(dir, path.join(project, '.claude', 'skills', name));
}
spawnSync('git', ['init', '-q'], { cwd: project });
process.on('exit', () => fs.rmSync(project, { recursive: true, force: true }));

// --- cases -------------------------------------------------------------------
const spec = JSON.parse(fs.readFileSync(path.join(__dirname, 'triggers.json'), 'utf8'));
const cases = [];
for (const [skill, c] of Object.entries(spec)) {
  if (skill.startsWith('_') || (ONLY && skill !== ONLY)) continue;
  if (!skills[skill]) {
    console.error(`triggers.json names unknown skill: ${skill}`);
    process.exit(2);
  }
  for (const p of c.should_trigger || []) cases.push({ skill, prompt: p, expect: true });
  for (const p of c.should_not_trigger || []) cases.push({ skill, prompt: p, expect: false });
}
if (!cases.length) {
  console.error(ONLY ? `no cases for ${ONLY}` : 'no cases');
  process.exit(2);
}

// --- run one case --------------------------------------------------------------
const DISALLOWED = ['Bash', 'Read', 'Write', 'Edit', 'Glob', 'Grep', 'WebFetch', 'WebSearch', 'Agent', 'NotebookEdit'];
function run(c) {
  return new Promise((resolve) => {
    const argv = ['-p', c.prompt, '--output-format', 'stream-json', '--verbose', '--max-turns', '1',
      '--allowedTools', 'Skill', '--disallowedTools', ...DISALLOWED];
    if (MODEL) argv.push('--model', MODEL);
    const child = spawn('claude', argv, { cwd: project, stdio: ['ignore', 'pipe', 'pipe'] });
    let buf = '';
    const loaded = [];
    const timer = setTimeout(() => child.kill('SIGTERM'), TIMEOUT_MS);
    child.stdout.on('data', (d) => {
      buf += d;
      let i;
      while ((i = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, i);
        buf = buf.slice(i + 1);
        let ev;
        try { ev = JSON.parse(line); } catch { continue; }
        for (const part of ev?.message?.content || []) {
          if (part.type === 'tool_use' && part.name === 'Skill' && part.input?.skill) {
            // Plugin or scoped skills look like "plugin:name"; compare the name.
            loaded.push(String(part.input.skill).split(':').pop());
          }
        }
      }
    });
    child.on('close', () => {
      clearTimeout(timer);
      const hit = loaded.includes(c.skill);
      resolve({ ...c, loaded, pass: hit === c.expect });
    });
  });
}

// --- pool -----------------------------------------------------------------------
(async () => {
  console.log(`${cases.length} cases, ${Object.keys(skills).length} skills linked, concurrency ${CONCURRENCY}`);
  console.log('Note: same-named skills in ~/.claude/skills shadow this repo\'s copies (./link-skill.sh --check).\n');
  const results = [];
  let next = 0;
  async function worker() {
    while (next < cases.length) {
      const c = cases[next++];
      const r = await run(c);
      results.push(r);
      const mark = r.pass ? 'ok  ' : 'FAIL';
      const want = r.expect ? 'should load' : 'must not load';
      console.log(`${mark} ${r.skill.padEnd(18)} ${want.padEnd(13)} loaded: ${r.loaded.join(', ') || '(none)'}  — "${r.prompt.slice(0, 70)}"`);
    }
  }
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, cases.length) }, worker));

  const failed = results.filter((r) => !r.pass);
  const bySkill = {};
  for (const r of results) {
    bySkill[r.skill] ??= { pass: 0, total: 0 };
    bySkill[r.skill].total++;
    if (r.pass) bySkill[r.skill].pass++;
  }
  console.log('\nPer skill:');
  for (const [s, v] of Object.entries(bySkill).sort()) console.log(`  ${s.padEnd(18)} ${v.pass}/${v.total}`);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (JSON_OUT) fs.writeFileSync(JSON_OUT, JSON.stringify(results, null, 2));
  process.exitCode = failed.length ? 1 : 0;
})();
