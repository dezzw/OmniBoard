# 17 — Versioning and Compatibility

## Purpose

Define versioning for OPP, Render IR, provider APIs, and how capability negotiation plus golden fixtures keep the monorepo compatible.

## Versioned surfaces

| Surface | Scheme | Compatibility rule |
| ------- | ------ | ------------------ |
| OPP / Client / Sync protocols | `major.minor` | Negotiate on initialize; minor adds optional capabilities; major may remove after deprecation |
| Render IR `schemaVersion` | `major.minor` | Renderers implement **N and N−1**; unknown fields ignored; unknown required nodes use fallback |
| Provider package | semver in manifest | Core advertises `oppVersion` + capability set |
| Error catalog codes | Stable ints | New codes in minor; reuse forbidden |

## Capability negotiation (LSP pattern)

1. Core sends desired `oppVersion` + capability object.
2. Provider responds with supported subset.
3. Intersection wins; missing capabilities disable features (e.g. no `items.pull` → Core won’t call pull methods).
4. Major mismatch → fail `initialize` with clear error; do not half-run.

## Deprecation policy

1. Announce deprecation in docs/RFCs with replacement capability or field.
2. Keep deprecated members working through at least one minor on both sides.
3. Remove only on major; Core and official SDKs ship overlapping support windows.
4. Golden fixtures retain “legacy accept” cases until removal.

## Render IR compatibility

```
Provider emits schemaVersion 1.1
Renderer understands 1.0 and 1.1 → ok
Renderer understands 1.0 only → ignore unknown optional fields; fallback unknown nodes
Renderer understands 2.x only, document is 1.0 → must still render 1.0 (N−1) or show placeholder
```

Core validates against the declared version’s schema when known; unknown future minor of same major → validate known subset + passthrough unknowns for renderers.

## Conformance suite

Long-term contract:

```
packages/protocol/
  schemas/           # JSON Schema
  fixtures/opp/      # golden request/response/notification JSON
  fixtures/render/   # golden Render IR trees + expected degrade outputs
```

Rules:

1. Protocol fixtures are **source of truth**; SDKs are generated or tested against them ([21](21-risks-and-tradeoffs.md)).
2. CI (later) fails on fixture regressions.
3. Docs examples in `docs/architecture/` **should** match fixtures once they exist; fixtures win on conflict.

## Normative rules

1. Adding an optional capability **shall not** require a major bump.
2. Removing or renaming a method **shall** require a major bump and deprecation window.
3. Official Apple renderers **shall** ship with N and N−1 Render IR support.
4. Providers **shall** declare `oppVersion` and package semver in the manifest.

## Non-goals

- Supporting infinite historical majors in one binary
- Per-customer protocol dialects
- Silent best-effort parsing that invents meaning for unknown required methods

## Tradeoffs

Capability negotiation adds handshake complexity versus “always latest,” but prevents OSS-ification and SDK drift across languages.

## Related

- [08-plugin-protocol.md](08-plugin-protocol.md)
- [05-rendering-schema.md](05-rendering-schema.md)
- [20-roadmap.md](20-roadmap.md)
