# 19 — Repository Layout

## Purpose

Map the monorepo structure, ownership boundaries, and how documentation relates to future code packages. Prefer one protocol version across Core, Hub, SDKs, and clients (VS Code / Home Assistant style).

## Toolchain

- **Core, Hub, protocol, script providers:** root **Nix flake** (`nix develop` / direnv `use flake`). Do not rely on host `rustup`. See [docs/dev-environment.md](../dev-environment.md).
- **Apple clients (`clients/apple`):** host **Xcode / Swift** on macOS — not the flake.

## Tree

```
omniboard/
  README.md
  ARCHITECTURE.md
  docs/
    architecture/     # normative architecture (this set)
    rfcs/             # future change proposals
  packages/
    protocol/         # JSON Schemas, golden fixtures (later)
    sdks/             # TypeScript, Python, Go, Rust SDKs (later)
  core/               # Rust Core library + local embed (later)
  hub/                # Headless deploy of Core (later)
  clients/
    apple/            # SwiftUI apps & extensions (later)
  providers/          # Reference providers (later)
  tools/              # Linters, protocol conformance runners (later)
```

Directories exist now as reserved scaffolds with stub READMEs; implementation code is out of scope for this phase.

## Ownership

| Path | Owns | Must not own |
| ---- | ---- | ------------ |
| `docs/architecture/` | Normative design | Runtime code |
| `docs/rfcs/` | Proposed changes | Silent protocol edits without RFC when process is active |
| `packages/protocol/` | Schemas + fixtures (source of truth for wires) | Provider business logic |
| `packages/sdks/` | Language helpers binding to protocol | Divergent dialects |
| `core/` | ItemStore, OPP host, EventBus, Sync client, permissions | SwiftUI views; domain APIs |
| `hub/` | Packaging/deploy, scheduler, webhook ingress | Forked protocol |
| `clients/apple/` | Renderers, BoardSurface UX, XPC client | Direct provider process management (delegate to Core) |
| `providers/` | Reference domain providers | Core internals |
| `tools/` | Conformance, codegen, linters | Production secrets |

## Monorepo rationale

1. Single OPP / Render IR version across all components.
2. Golden fixtures shared by Core, SDKs, and renderers.
3. Atomic PRs for protocol + implementation updates.
4. Hub stays a deploy flavor of Core, not a separate product repo ([21](21-risks-and-tradeoffs.md)).

## Doc → code promotion path

```
docs/architecture examples
        │
        ▼
packages/protocol schemas + fixtures   (normative machine-readable)
        │
        ├── core/ + hub/ validate & speak
        ├── packages/sdks/ generate or test
        └── clients/apple/ parse Render IR
```

When fixtures exist, they override informal doc examples on conflict ([17](17-versioning.md)).

## Normative rules

1. Protocol-breaking changes **shall** update `packages/protocol/` and docs in the same change set (once code exists).
2. Reference providers **shall** live in-repo for conformance demos.
3. Secrets and `.env` files **shall not** be committed.
4. Empty package dirs **may** contain only README placeholders until implementation phases begin.

## Non-goals

- Polyrepo for v1
- Publishing Hub as an unrelated SaaS codebase
- Storing large binary provider artifacts in git (use releases later)

## Tradeoffs

A monorepo can feel large early, but prevents the worse cost of multi-repo protocol drift across Swift, Rust, and script providers.

## Related

- [01-system-overview.md](01-system-overview.md)
- [20-roadmap.md](20-roadmap.md)
- [ARCHITECTURE.md](../../ARCHITECTURE.md)
