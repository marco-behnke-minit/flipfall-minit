// meta.json is what the Creator Console reads to pre-fill the drop, and its
// `config` block is what the create wizard enforces. src/constants.gd is what
// the running game reads and clamps against. A wizard and a runtime enforcing
// different rules is a bug that would only surface in production, so this fails
// the build if the two ever disagree on a key, type, default or bound.
//
//   node tools/check-meta.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const project = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const meta = JSON.parse(readFileSync(resolve(project, 'meta.json'), 'utf8'));
const gd = readFileSync(resolve(project, 'src/constants.gd'), 'utf8');

const errors = [];

// Pull the CONFIG entries straight out of the GDScript so there is no second
// copy of the numbers to drift.
const constants = Object.fromEntries(
  [...gd.matchAll(/^const (\w+) := (-?[\d.]+)\s*(?:#.*)?$/gm)].map(([, k, v]) => [k, Number(v)])
);
const resolveValue = (token) =>
  token in constants ? constants[token] : Number(token);

const configBlock = gd.match(/const CONFIG := \[([\s\S]*?)\n\]/);
if (!configBlock) {
  console.error('could not find CONFIG in src/constants.gd');
  process.exit(1);
}
const gdConfig = [...configBlock[1].matchAll(
  /\{"key": "(\w+)", "value_type": "(\w+)", "value": ([\w.]+), "min": ([\w.]+), "max": ([\w.]+)\}/g
)].map(([, key, valueType, value, min, max]) => ({
  key,
  valueType,
  value: resolveValue(value),
  min: resolveValue(min),
  max: resolveValue(max),
}));

if (!Array.isArray(meta.config)) errors.push('meta.json has no config array');
if (meta.schemaVersion !== 1) errors.push(`schemaVersion is ${meta.schemaVersion}, expected 1`);
if (meta.resultSorting !== 'highestScore') {
  errors.push(`resultSorting is ${meta.resultSorting}, expected highestScore — Flipfall's score is higher-is-better`);
}

const seen = new Set();
for (const entry of meta.config ?? []) {
  const key = String(entry.key).trim();
  if (seen.has(key)) errors.push(`duplicate config key "${key}" (after trimming)`);
  seen.add(key);

  const spec = gdConfig.find((c) => c.key === key);
  if (!spec) {
    errors.push(`meta.json declares "${key}", which src/constants.gd does not`);
    continue;
  }
  for (const field of ['valueType', 'value', 'min', 'max']) {
    if (entry[field] !== spec[field]) {
      errors.push(`"${key}".${field}: meta.json=${entry[field]} constants.gd=${spec[field]}`);
    }
  }
  if (entry.value < entry.min || entry.value > entry.max) {
    errors.push(`"${key}": default ${entry.value} is outside its own ${entry.min}..${entry.max}`);
  }
  if (typeof entry.moddable !== 'boolean') errors.push(`"${key}": moddable must be a boolean`);
}

for (const spec of gdConfig) {
  if (!seen.has(spec.key)) errors.push(`src/constants.gd declares "${spec.key}", which meta.json does not`);
}

// startLevel / endLevel are locked on purpose: a mod that swapped the room set
// would report a score for a run nobody played.
for (const key of ['startLevel', 'endLevel']) {
  const entry = (meta.config ?? []).find((c) => c.key === key);
  if (entry && entry.moddable !== false) errors.push(`"${key}" must be moddable:false`);
}

if (errors.length) {
  console.error(`meta.json check failed (${errors.length}):`);
  for (const e of errors) console.error('  ' + e);
  process.exit(1);
}
console.log(`meta.json agrees with src/constants.gd on all ${gdConfig.length} config keys.`);
