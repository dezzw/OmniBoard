# Development environment

## Core / protocol / providers (Nix flake)

OmniBoard uses a **Nix flake** for Rust Core, protocol tooling, and script providers:

```bash
nix develop
```

Do not rely on host `rustup` for Core builds.

## Apple clients (host Swift)

`clients/apple` uses the **system Swift / Xcode** toolchain on macOS. No flake packages are required for that subtree.

```bash
cd clients/apple
swift run OmniBoardKitSmoke
swift run OmniBoardApp
```

## Checks

```bash
nix develop -c just check          # protocol + core tests
nix develop -c just run-clock      # Core daemon + clock provider
cd clients/apple && swift run OmniBoardKitSmoke
```

See root [`flake.nix`](../flake.nix) and [`clients/apple/README.md`](../clients/apple/README.md).
