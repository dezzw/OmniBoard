# 20 — Roadmap

## Purpose

Phased delivery ordered by **dependency**, not calendar estimates. Each phase unlocks the next; dates are intentionally omitted.

## Phase 0 — Architecture foundation (current)

- Normative docs under `docs/architecture/`
- Root `README.md` + `ARCHITECTURE.md`
- Reserved monorepo directories
- RFC folder stub

**Exit criteria:** Locked decisions documented; cross-links consistent; ready for protocol packaging.

## Phase 1 — Protocol package

- JSON Schemas for OPP messages, Items, Render IR, manifests
- Golden fixtures + conformance runner skeleton in `tools/`
- Error code + capability registries as data

**Exit criteria:** Fixtures validate; docs examples aligned with schemas.

## Phase 2 — Core MVP (local)

- Rust Core: ItemStore (SQLite), ProviderSupervisor (stdio OPP), EventBus, ActionRouter, PermissionBroker (baseline), Render IR validation
- Minimal Client Protocol for a single Apple app target
- One reference provider (e.g. static/demo or clock) in any language

**Exit criteria:** App shows provider items offline after provider stop; action round-trip works.

## Phase 3 — Apple surfaces

- WidgetKit + snapshot adapter
- Live Activities / Dynamic Island where applicable
- Menu bar and/or Watch complication spike
- BoardSurface editor basics

**Exit criteria:** Same Render IR drives ≥2 surface classes with degrade behavior tested.

## Phase 4 — Auth, permissions hardening, packaging

- Keychain secret refs + OAuth/device flow UX
- Network allowlist enforcement on target OS
- Signed provider package format
- Additional official SDK (TypeScript or Python)

**Exit criteria:** Third-party-style provider install with grants; auth expiry degrades cleanly.

## Phase 5 — Hub (optional path)

- Headless Core deploy
- Scheduler / webhooks
- Sync Protocol for items + user-state CRDT
- Encrypted secret store

**Exit criteria:** Two devices sync user state; Hub-hosted provider feeds both; local-only mode still works with Hub wiped.

## Phase 6 — Ecosystem polish

- More SDKs (Go, Rust)
- Conformance CI required for providers/
- Design guidelines for Render IR density
- RFC process in active use for protocol changes

**Exit criteria:** External provider can pass conformance without Core source changes.

## Explicitly unordered / later

- gRPC transport adapter
- MessagePack default for hot paths
- Multi-tenant Hub RBAC
- Non-Apple first-party clients

## Normative rules for planning

1. Roadmap phases **shall not** include week/month estimates in this document.
2. Hub **shall not** precede local Core MVP.
3. Protocol fixtures **shall** precede multiple SDKs.
4. No phase requires abandoning local-only operation.

## Related

- [19-repository-layout.md](19-repository-layout.md)
- [21-risks-and-tradeoffs.md](21-risks-and-tradeoffs.md)
- [17-versioning.md](17-versioning.md)
