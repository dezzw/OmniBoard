#!/usr/bin/env node
/**
 * Validate golden fixtures in packages/protocol against JSON Schemas.
 * Run via: nix develop -c just protocol
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "../..");
const protocolRoot = path.join(root, "packages/protocol");
const schemasDir = path.join(protocolRoot, "schemas");

const require = createRequire(import.meta.url);

function loadAjv() {
  try {
    const Ajv = require("ajv").default;
    const addFormats = require("ajv-formats").default;
    return { Ajv, addFormats };
  } catch {
    console.error(
      "Missing ajv. Inside nix develop, run: just deps"
    );
    process.exit(1);
  }
}

const { Ajv, addFormats } = loadAjv();

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function walkJsonFiles(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walkJsonFiles(full));
    else if (entry.name.endsWith(".json")) out.push(full);
  }
  return out;
}

const ajv = new Ajv({
  allErrors: true,
  strict: false,
  validateSchema: false,
});
addFormats(ajv);

const byId = new Map();
for (const file of walkJsonFiles(schemasDir)) {
  const schema = readJson(file);
  const rel = path.relative(schemasDir, file).split(path.sep).join("/");
  const id = schema.$id ?? `https://omniboard.dev/schemas/${rel}`;
  if (!schema.$id) schema.$id = id;
  if (byId.has(id)) continue;
  byId.set(id, schema);
  ajv.addSchema(schema);
}

const cases = [
  {
    fixture: "fixtures/opp/initialize-request.json",
    schemaId: "https://omniboard.dev/schemas/opp/initialize-params.json",
    extract: (doc) => doc.params,
  },
  {
    fixture: "fixtures/opp/initialize-result.json",
    schemaId: "https://omniboard.dev/schemas/opp/initialize-result.json",
    extract: (doc) => doc.result,
  },
  {
    fixture: "fixtures/opp/items-changed-delta.json",
    schemaId: "https://omniboard.dev/schemas/opp/items-changed.json",
    extract: (doc) => doc.params,
  },
  {
    fixture: "fixtures/opp/provider-status-degraded.json",
    schemaId: "https://omniboard.dev/schemas/opp/provider-status.json",
    extract: (doc) => doc.params,
  },
  {
    fixture: "fixtures/opp/actions-execute.json",
    schemaId: "https://omniboard.dev/schemas/opp/actions-execute.json",
    extract: (doc) => doc.params,
  },
  {
    fixture: "fixtures/render/flight-widget.json",
    schemaId: "https://omniboard.dev/schemas/render-ir.json",
  },
  {
    fixture: "fixtures/render/unknown-node-with-fallback.json",
    schemaId: "https://omniboard.dev/schemas/render-ir.json",
  },
  {
    fixture: "fixtures/items/flight-status.json",
    schemaId: "https://omniboard.dev/schemas/item.json",
  },
  {
    fixture: "fixtures/items/manifest-flights.json",
    schemaId: "https://omniboard.dev/schemas/manifest.json",
  },
];

let failed = 0;
for (const c of cases) {
  const fixturePath = path.join(protocolRoot, c.fixture);
  const doc = readJson(fixturePath);
  const data = c.extract ? c.extract(doc) : doc;
  const validate = ajv.getSchema(c.schemaId);
  if (!validate) {
    console.error(`FAIL ${c.fixture}: schema not found ${c.schemaId}`);
    failed++;
    continue;
  }
  const ok = validate(data);
  if (!ok) {
    console.error(`FAIL ${c.fixture}`);
    console.error(validate.errors);
    failed++;
  } else {
    console.log(`ok   ${c.fixture}`);
  }
}

const caps = readJson(path.join(protocolRoot, "registries/capabilities.json"));
const errors = readJson(path.join(protocolRoot, "registries/error-codes.json"));
const hints = readJson(path.join(protocolRoot, "registries/surface-hints.json"));
const nodes = readJson(path.join(protocolRoot, "registries/render-node-types.json"));
if (!caps.capabilities?.length || !errors.codes?.length || !hints.surfaceHints?.length || !nodes.nodeTypes?.length) {
  console.error("FAIL registries incomplete");
  failed++;
} else {
  console.log("ok   registries");
}

if (failed) {
  console.error(`\n${failed} failure(s)`);
  process.exit(1);
}
console.log("\nAll protocol fixtures valid.");
