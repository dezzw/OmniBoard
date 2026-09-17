# OmniBoard

OmniBoard is a SwiftUI multiplatform app skeleton for iOS and macOS. The project is intentionally thin: a runnable shell with a placeholder home screen you can extend with real board features later.

## Requirements

- macOS with **Xcode 16** or later
- Apple SDKs for **iOS 17+** and **macOS 14+**

## Open in Xcode

1. Clone this repository.
2. Open `OmniBoard.xcodeproj` in Xcode (double-click the project file or use **File → Open**).
3. Select the **OmniBoard** scheme.
4. Choose a run destination:
   - **My Mac** for the macOS app
   - An **iPhone** or **iPad simulator** for iOS
5. Press **Run** (⌘R).

On first run, Xcode may prompt you to set a **Development Team** under **Signing & Capabilities** so the app can launch on a device or simulator. The bundle identifier is `dev.omniboard.app`; change it to match your team if needed.

## Project layout

```
OmniBoard/
  OmniBoardApp.swift          # @main app entry point
  Views/
    OmniBoardView.swift       # Placeholder home / board screen
  Assets.xcassets/            # App icon and accent color slots
OmniBoard.xcodeproj/          # Xcode project and shared scheme
```

Shared SwiftUI code targets both iOS and macOS from a single **OmniBoard** app target. Platform-specific UI can be added later with `#if os(iOS)` / `#if os(macOS)` when needed.

## Build from the command line

On a Mac with Xcode installed:

```bash
# macOS
xcodebuild -project OmniBoard.xcodeproj -scheme OmniBoard -destination 'platform=macOS' build

# iOS Simulator
xcodebuild -project OmniBoard.xcodeproj -scheme OmniBoard \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Continuous integration

GitHub Actions builds on **macOS** runners (see [`.github/workflows/build.yml`](.github/workflows/build.yml)). Linux-based cloud agents and CI jobs cannot compile SwiftUI or Apple platform targets; only the macOS workflow validates that the project builds.

## Status

Scaffold only — no networking, persistence, or business logic yet. Extend `OmniBoardView` and add models/services as the product takes shape.
