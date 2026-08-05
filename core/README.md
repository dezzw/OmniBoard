# Core (Rust)

Local OmniBoard Core: ItemStore (SQLite), OPP framing, ProviderSupervisor, Client Protocol Unix socket, EventBus, Render IR soft-validation.

## Build / test (Nix flake)

```bash
nix develop -c just check
nix develop -c just run-clock
```

`run-clock` starts Core, supervises `providers/clock`, and serves Client Protocol at `/tmp/omniboard.sock`.

Apple UI connects with host Swift — see [`clients/apple`](../clients/apple/).
