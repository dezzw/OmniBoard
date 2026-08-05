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

## Development

**Rust / protocol / providers:** Nix flake only (`nix develop`). See [docs/dev-environment.md](docs/dev-environment.md).

**Apple clients:** host Swift / Xcode on macOS — **no Nix**. See [clients/apple/README.md](clients/apple/README.md).

```bash
nix develop
just deps && just check
just run-clock          # Core + clock provider on /tmp/omniboard.sock

# separate terminal (host Swift):
cd clients/apple && swift run OmniBoardApp
```

## Status

Architecture docs, protocol package, Rust Core (ItemStore, OPP supervisor, Client Protocol socket), Python clock provider, and SwiftUI Apple scaffold. Roadmap: [20-roadmap.md](docs/architecture/20-roadmap.md).
