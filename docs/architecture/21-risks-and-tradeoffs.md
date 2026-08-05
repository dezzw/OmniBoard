# 21 — Risks and Tradeoffs

## Purpose

Call out architectural risks, rejected alternatives, and mitigations so future RFCs do not re-litigate locked decisions without new evidence.

## Risks

### Render IR under / over-specification

| Failure mode | Symptom | Mitigation |
| ------------ | ------- | ---------- |
| Too weak | Ugly, inconsistent UI across providers | Small semantic vocabulary + reference design guidelines + strong fallbacks |
| Too strong | Provider burden; forever chasing SwiftUI | Freeze v1 vocabulary; prefer composition over new primitives; N/N−1 policy |

### WidgetKit / ActivityKit constraints

Apple timelines and budget limits may force Core-side snapshot materialization. **Mitigation:** renderer adapters own platform constraints; providers stay declarative ([05](05-rendering-schema.md), [13](13-caching.md)).

### Protocol ossification vs churn

Either freezing too early or changing weekly breaks SDKs. **Mitigation:** capability negotiation + golden conformance fixtures from day one of Phase 1 ([17](17-versioning.md)).

### Multi-language SDK drift

Hand-written SDKs invent dialects. **Mitigation:** `packages/protocol/` fixtures are source of truth; SDKs generated or tested against them.

### Hub becoming a second product

Separate Hub codebase forks protocols and features. **Mitigation:** Hub is Core in headless mode; `hub/` is packaging/deploy ([02](02-core-responsibilities.md), [19](19-repository-layout.md)).

### Security of third-party providers

Untrusted code near personal data. **Mitigation:** process isolation, permissions, signed packages, `shell` disabled by default ([12](12-permissions.md), [18](18-security-model.md)). Residual: OS sandbox limits.

### Sync complexity

One global CRDT over items + layout + config is operationally painful. **Mitigation:** split sync domains — items (revision LWW), user state (CRDT), config (versioned + UI resolve) ([14](14-synchronization.md)).

## Rejected alternatives

| Alternative | Why rejected |
| ----------- | ------------ |
| In-process Swift/Go plugins | Crash coupling; language lock-in; weak sandbox |
| gRPC as required provider API | High friction for script providers; allowed later as adapter only |
| REST-only providers | Weak bidirectional push, lifecycle, streaming |
| Providers return SwiftUI | Breaks multi-surface + sandbox |
| Providers return HTML | Poor native surfaces; XSS-shaped risk |
| Raw data + Core templates only | Reintroduces domain knowledge into Core/UI |
| Go as Core | Excellent servers; weaker in-app embed on Apple vs Rust |
| Hub-required cloud | Violates local-first; phoning home not required |
| Single global CRDT for all state | Wrong tool for provider-authoritative high-churn items |

## Locked decisions (do not silently reverse)

1. Runtime + Providers + Renderers + optional Hub
2. OPP = JSON-RPC 2.0 + capabilities; stdio default
3. Core/Hub Rust; clients SwiftUI; providers any language
4. Provider-authoritative opaque-but-validated items
5. Declarative Render IR middle ground
6. Three-layer transport abstraction
7. Split sync domains
8. Monorepo with protocol package as contract hub

Reversal requires an RFC in `docs/rfcs/` with explicit migration cost.

## Non-goals of this document

- Quantifying residual risk in dollars or CVSS for every threat
- Choosing Automerge vs other CRDT implementations (deferred to Hub phase RFC)
- Ranking providers for trustworthiness

## Related

- [ARCHITECTURE.md](../../ARCHITECTURE.md)
- [20-roadmap.md](20-roadmap.md)
- [18-security-model.md](18-security-model.md)
