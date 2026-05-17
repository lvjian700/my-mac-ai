# Agent Guide - ical-mac

Native macOS calendar assistant. Built from scratch in SwiftUI with direct EventKit calendar access and a Swift Anthropic Messages API client.

## Build & Run

```bash
swift build              # debug build
swift build -c release   # release build
swift test               # unit tests with fakes
swift run ical-mac       # run the SwiftUI executable
make app                 # create .build/ical-mac.app
make install             # install app to ~/Applications/ical-mac.app
```

Requires macOS 14+.

## Architecture

**Tech stack:** Swift 6, SwiftUI, EventKit, Security/Keychain, URLSession.

**Boundaries:**
- `ICalMacCore` owns calendar models, EventKit access, Anthropic API/tool loop, memory files, prompt loading, and Keychain storage.
- `ICalMacApp` owns SwiftUI scenes, app state, settings, chat transcript, and context pane.

Use fakes for tests. Do not depend on real Calendar data or live Anthropic calls in unit tests.

## Notes

This app does not reuse TypeScript, Bun, Ink, or the `ical-chat` runtime.
