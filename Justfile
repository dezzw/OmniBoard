# OmniBoard task runner — always run inside `nix develop`.

default:
    @just --list

# Enter reminder
flake:
    @echo "Use: nix develop"

# Install JS deps for conformance (uses flake node)
deps:
    npm install --prefix tools/conformance

# Validate protocol schemas + golden fixtures
protocol:
    node tools/conformance/validate.mjs

# Core tests (once crate exists)
core-test:
    cargo test --manifest-path core/Cargo.toml

check: protocol
