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

# Core unit tests (includes supervisor integration when python3 is available)
core-test:
    cargo test -p omniboard-core

# Run Core + clock provider (Client Protocol on --socket)
run-clock:
    mkdir -p {{justfile_directory()}}/.data
    cargo run -p omniboard-core --bin omniboard -- run \
      --provider-cmd python3 \
      --provider-arg providers/clock/provider.py \
      --provider-cwd {{justfile_directory()}} \
      --db {{justfile_directory()}}/.data/omniboard.sqlite \
      --socket /tmp/omniboard.sock

check: protocol core-test
