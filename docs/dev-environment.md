# Development environment (Nix flake)

OmniBoard uses a **Nix flake** as the only supported toolchain. Prefer `nix develop` (or direnv + `use flake`) over host `rustup` / Homebrew compilers.

```bash
nix develop
# or, with direnv:
# echo 'use flake' > .envrc && direnv allow
```

## Provided tools

| Tool | Role |
| ---- | ---- |
| Rust stable (+ rustfmt, clippy, rust-analyzer) | `core/`, `hub/` |
| Node.js 22 | protocol package, conformance tools, TS SDKs/providers |
| Python 3 | script providers / helpers |
| SQLite, OpenSSL | Core native linkage |
| jq, just | scripting |

## Checks

```bash
nix develop -c node tools/conformance/validate.mjs
nix develop -c cargo test --manifest-path core/Cargo.toml
```

See root [`flake.nix`](../flake.nix).
