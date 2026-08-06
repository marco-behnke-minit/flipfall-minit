// Prove the validator in tools/lib/jsonschema.mjs actually rejects bad input.
//
//   node tools/test-schema.mjs
//
// A hand-written validator that silently passes everything is worse than no
// validator, because it looks like coverage. So: the real meta.json must pass,
// and each deliberately broken variant must fail.
import { readFileSync } from 'node:fs';
import { validate } from './lib/jsonschema.mjs';

const schema = JSON.parse(readFileSync(new URL('../meta.schema.json', import.meta.url), 'utf8'));
const meta = JSON.parse(readFileSync(new URL('../meta.json', import.meta.url), 'utf8'));

let failures = 0;

function expectValid(label, doc) {
  const errors = validate(doc, schema);
  if (errors.length) {
    failures++;
    console.log(`FAIL  ${label} should be valid, but: ${errors[0]}`);
  } else {
    console.log(`ok    ${label}`);
  }
}

function expectInvalid(label, mutate) {
  const doc = structuredClone(meta);
  mutate(doc);
  const errors = validate(doc, schema);
  if (!errors.length) {
    failures++;
    console.log(`FAIL  ${label} should have been rejected`);
  } else {
    console.log(`ok    ${label} rejected — ${errors[0]}`);
  }
}

expectValid('the real meta.json', meta);

// The typo the design document calls out by name: a schema layer exists so a
// misspelled field fails loudly instead of being silently ignored.
expectInvalid('a typo\'d "moddible" field', (d) => {
  d.config[0].moddible = d.config[0].moddable;
  delete d.config[0].moddable;
});
// The schema is deliberately permissive at the top level and on schemaVersion —
// both are forward-compat hooks. Asserting that keeps a later tightening honest.
expectValid('an unknown top-level field (allowed by design)',
  { ...meta, somethingNew: 'hard' });
expectValid('an unknown schemaVersion (forward-compat hook)',
  { ...meta, schemaVersion: 2 });
expectValid('an empty title (length is not constrained)', { ...meta, title: '' });
expectInvalid('a wrong type on value', (d) => { d.config[0].value = 'three'; });
expectInvalid('a wrong type on title', (d) => { d.title = 42; });
expectInvalid('a bad resultSorting', (d) => { d.resultSorting = 'mostPoints'; });
expectInvalid('a missing config key', (d) => { delete d.config[0].key; });
expectInvalid('an empty config key', (d) => { d.config[0].key = ''; });
expectInvalid('a bad valueType', (d) => { d.config[0].valueType = 'integer'; });
expectInvalid('a config entry with neither value nor defaultValue', (d) => {
  delete d.config[0].value;
});
expectInvalid('range combined with min/max', (d) => {
  d.config[0].range = [1, 2, 3];
});
expectInvalid('config that is not an array', (d) => { d.config = {}; });
expectInvalid('an over-long config description', (d) => {
  d.config[0].description = 'x'.repeat(101);
});

console.log('');
if (failures) {
  console.log(`${failures} FAILURE(S)`);
  process.exit(1);
}
console.log('the schema validator rejects what it claims to reject');
