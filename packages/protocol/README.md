# OmniBoard Protocol

Machine-readable contracts for OmniBoard: JSON Schemas, capability/error registries, and golden fixtures.

Architecture docs in [`docs/architecture/`](../../docs/architecture/) are normative prose. **When fixtures and schemas exist, they win on conflict** ([17-versioning.md](../../docs/architecture/17-versioning.md)).

## Layout

```
packages/protocol/
  package.json
  schemas/
    common.json
    item.json
    manifest.json
    render-ir.json
    opp/
      initialize-params.json
      initialize-result.json
      items-changed.json
      actions-execute.json
      provider-status.json
      jsonrpc-error.json
  registries/
    capabilities.json
    error-codes.json
    surface-hints.json
    render-node-types.json
  fixtures/
    opp/
    render/
    items/
```

## Validate

From repo root:

```bash
node tools/conformance/validate.mjs
```
