# Apple clients (native macOS / Xcode)

SwiftUI renderers and Client Protocol client. **No Nix flake required** — use the system Swift / Xcode toolchain on macOS.

## Layout

| Path | Role |
| ---- | ---- |
| `Sources/OmniBoardKit` | Models, Render IR → SwiftUI, Unix-socket Core client |
| `Sources/OmniBoardApp` | macOS SwiftUI app scaffold |
| `Sources/OmniBoardKitSmoke` | Decode / model smoke checks (no Xcode.app required) |

## Run

Terminal A — Core + clock (Nix flake for Rust/Python only):

```bash
# from repo root
nix develop -c just run-clock
```

Terminal B — Apple (host Swift / Command Line Tools or Xcode):

```bash
cd clients/apple
swift run OmniBoardKitSmoke   # model/decode checks (no Xcode.app required)
swift run OmniBoardApp        # macOS UI; needs a GUI session
```

Open `Package.swift` in Xcode when you have full Xcode installed.

Default Client Protocol socket: `/tmp/omniboard.sock` (must match Core `--socket`).
