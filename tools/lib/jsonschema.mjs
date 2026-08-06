// A compact JSON Schema validator, covering exactly the keywords
// meta.schema.json uses — which is a mirror of the Creator Console's Zod source.
//
// Deliberately not a dependency: the schema is small and fixed, and the project
// otherwise needs no npm install to verify itself. Because a validator that
// silently passes bad input is worse than none, tools/test-schema.mjs feeds it
// deliberately broken documents and checks each one is rejected.
//
// Supported: $ref (local), type, const, enum, pattern, minimum, minLength,
// maxLength, maxItems, items, required, properties, additionalProperties,
// allOf, anyOf, not, if/then.

const typeOf = (v) =>
  v === null ? 'null' : Array.isArray(v) ? 'array' : Number.isInteger(v) ? 'integer' : typeof v;

const matchesType = (v, t) =>
  t === 'number' ? typeof v === 'number' : t === 'integer' ? Number.isInteger(v) : typeOf(v) === t;

function resolve(schema, root) {
  if (!schema || !schema.$ref) return schema;
  const path = schema.$ref.replace(/^#\//, '').split('/');
  let node = root;
  for (const part of path) node = node?.[part];
  if (!node) throw new Error(`unresolvable $ref: ${schema.$ref}`);
  // A sibling keyword next to $ref is not something this schema uses.
  return node;
}

/** Returns a list of human-readable problems; empty means valid. */
export function validate(value, schema, root = schema, path = '') {
  const errors = [];
  const s = resolve(schema, root);
  if (s === true || s === undefined) return errors;
  if (s === false) return [`${path || '(root)'}: not allowed here`];

  const at = path || '(root)';

  if (s.type !== undefined) {
    const types = Array.isArray(s.type) ? s.type : [s.type];
    if (!types.some((t) => matchesType(value, t))) {
      return [`${at}: expected ${types.join(' or ')}, got ${typeOf(value)}`];
    }
  }

  if (s.const !== undefined && JSON.stringify(value) !== JSON.stringify(s.const)) {
    errors.push(`${at}: must be ${JSON.stringify(s.const)}`);
  }
  if (s.enum !== undefined && !s.enum.some((e) => JSON.stringify(e) === JSON.stringify(value))) {
    errors.push(`${at}: must be one of ${s.enum.map((e) => JSON.stringify(e)).join(', ')}`);
  }

  if (typeof value === 'string') {
    if (s.pattern !== undefined && !new RegExp(s.pattern).test(value)) {
      errors.push(`${at}: does not match ${s.pattern}`);
    }
    if (s.minLength !== undefined && value.length < s.minLength) {
      errors.push(`${at}: shorter than ${s.minLength}`);
    }
    if (s.maxLength !== undefined && value.length > s.maxLength) {
      errors.push(`${at}: longer than ${s.maxLength}`);
    }
  }

  if (typeof value === 'number' && s.minimum !== undefined && value < s.minimum) {
    errors.push(`${at}: below minimum ${s.minimum}`);
  }

  if (Array.isArray(value)) {
    if (s.maxItems !== undefined && value.length > s.maxItems) {
      errors.push(`${at}: more than ${s.maxItems} items`);
    }
    if (s.items) {
      value.forEach((v, i) => errors.push(...validate(v, s.items, root, `${path}[${i}]`)));
    }
  }

  if (value && typeof value === 'object' && !Array.isArray(value)) {
    for (const key of s.required ?? []) {
      if (!(key in value)) errors.push(`${at}: missing required "${key}"`);
    }
    for (const [key, sub] of Object.entries(s.properties ?? {})) {
      if (key in value) errors.push(...validate(value[key], sub, root, path ? `${path}.${key}` : key));
    }
    if (s.additionalProperties === false) {
      for (const key of Object.keys(value)) {
        if (!(key in (s.properties ?? {}))) errors.push(`${at}: unexpected field "${key}"`);
      }
    }
  }

  for (const sub of s.allOf ?? []) errors.push(...validate(value, sub, root, path));

  if (s.anyOf) {
    const branches = s.anyOf.map((sub) => validate(value, sub, root, path));
    if (branches.every((b) => b.length)) {
      errors.push(`${at}: matches none of the ${s.anyOf.length} allowed shapes`);
    }
  }

  if (s.not && validate(value, s.not, root, path).length === 0) {
    errors.push(`${at}: matches a forbidden shape`);
  }

  if (s.if && validate(value, s.if, root, path).length === 0 && s.then) {
    errors.push(...validate(value, s.then, root, path));
  }

  return errors;
}
