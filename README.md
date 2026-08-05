# OmniBoard

OmniBoard is an Apple-first personal information surface: a local Core that hosts out-of-process providers, validates a declarative Render IR, and feeds SwiftUI renderers (app, widgets, Live Activities, Watch, menu bar). An optional headless Hub reuses the same Core for aggregation, scheduling, and multi-device sync.

This repository is currently in the **architecture documentation** phase. There is no application runtime yet. Normative protocols and schemas live under [`docs/architecture/`](docs/architecture/) and will later be promoted to [`packages/protocol/`](packages/protocol/).

## Quick links

| Document | Purpose |
| -------- | ------- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Vision, principles, system diagram, doc index |
| [docs/architecture/](docs/architecture/) | Normative architecture (01–21) |
| [docs/rfcs/](docs/rfcs/) | Future change proposals |

## Locked shape (summary)

- **Core + Hub:** Rust (documented intent; not implemented yet)
- **Clients:** Swift / SwiftUI only
- **Providers:** any language via **OPP** (JSON-RPC 2.0 + capabilities, stdio by default)
- **Rendering:** declarative **Render IR** — providers describe *what*; Core/renderers decide *how*
- **Local-first:** SQLite on device; Hub is optional; no cloud required

## Repository layout

```
omniboard/
  README.md
  ARCHITECTURE.md
  docs/architecture/
  docs/rfcs/
  packages/protocol/   # schemas & fixtures (later)
  packages/sdks/       # language SDKs (later)
  core/                # Rust core (later)
  hub/                 # headless deploy (later)
  clients/apple/       # SwiftUI apps/extensions (later)
  providers/           # reference providers (later)
  tools/               # linters, conformance (later)
```

See [19-repository-layout.md](docs/architecture/19-repository-layout.md) for ownership rules.

## Development (Nix flake)

**Always use the Nix flake toolchain** — do not rely on host `rustup` / Homebrew compilers.

```bash
nix develop
just deps      # once: install conformance npm deps
just protocol  # validate packages/protocol fixtures
```

Details: [docs/dev-environment.md](docs/dev-environment.md).

## Status

Architecture docs + protocol package in progress. Roadmap: [20-roadmap.md](docs/architecture/20-roadmap.md).
