# OmniBoard

iPhone-only SwiftUI app shell with Board, Service, and Settings tabs.

## Requirements

- Xcode 16+
- iOS 18+ (iPhone only)

## Open and run

1. Open `OmniBoard.xcodeproj` in Xcode.
2. Select the **OmniBoard** scheme and an **iPhone** simulator.
3. Run (⌘R). Set a Development Team under Signing if prompted.

## Tabs

- **Board** — hardcoded weather stub cards (no network)
- **Service** — display-only local status rows
- **Settings** — appearance and on-device metadata

Light and dark mode follow the system. The tab bar uses system chrome; cards and lists stay opaque.

## Tests

```bash
xcodebuild \
  -project OmniBoard.xcodeproj \
  -scheme OmniBoard \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO \
  build test
```

## CI

GitHub Actions builds and tests on the iOS Simulator only (see `.github/workflows/ios.yml`).
