# Agent Guide - ical-mac

Native macOS calendar assistant. Built from scratch in SwiftUI with direct EventKit calendar access and a Swift Anthropic Messages API client.

## Build & Run

```bash
swift build              # debug build
swift build -c release   # release build
swift test               # unit tests with fakes
./script/build_and_run.sh # build .app bundle and launch it
make app                 # create .build/ical-mac.app
make dmg                 # create dist/ical-mac-<version>.dmg for personal use
make install             # install app to ~/Applications/ical-mac.app
```

Requires macOS 14+.

Prefer `./script/build_and_run.sh` or `make app` for local UI inspection. Do not
use the raw SwiftPM executable as the normal GUI run path; the app should launch
as a macOS `.app` bundle so window activation and Calendar permission behavior
match user runs.

`make dmg` defaults to ad-hoc signing for personal-use DMGs. For a public
Developer ID release, run it with `REQUIRE_DEVELOPER_ID_DMG=1` and a
`CODESIGN_IDENTITY="Developer ID Application: ..."` value.

## Xcode

```bash
make xcode        # open the SwiftPM package in Xcode
make xcode-build  # validate the Xcode-generated ical-mac scheme
make xcode-test   # run package tests through Xcode
```

In Xcode, select the `ical-mac` scheme and `My Mac`, then Run. The package keeps
skill lookup independent of Xcode's generated `.swiftpm/xcode` working directory,
so breakpoints in `Sources/ICalMacApp` and `Sources/ICalMacCore` work normally.

## Architecture

**Tech stack:** Swift 6, SwiftUI, EventKit, Security/Keychain, URLSession.

**Boundaries:**
- `ICalMacCore` owns calendar models, EventKit access, OpenAI API/tool loop, memory files, prompt loading, and Keychain storage.
- `ICalMacUI` owns `AppModel`, SwiftUI views, settings, chat transcript, conversation sidebar, and the read-only week calendar surface.
- `ICalMacApp` owns the SwiftUI app entrypoint, app delegate, main window scene, and settings scene.

Use fakes for tests. Do not depend on real Calendar data or live API calls in unit tests.

### Agent Flow

Single-agent design. `AssistantService` runs a tool loop with Cali as the sole agent and all five calendar tools exposed directly.

```
User message
  └─► AssistantService  (Cali — single agent)
        ├─ tool: list_calendars
        ├─ tool: list_events
        ├─ tool: create_event
        ├─ tool: update_event
        └─ tool: write_memory
        └─ returns response
```

**`AssistantService`** (`Services/AssistantService.swift`) — Maintains multi-turn `inputHistory`. Builds the system prompt each turn, runs the tool loop via `CalendarToolExecutor`, and returns the final assistant text.

**`PromptStore`** (`Stores/PromptStore.swift`) — Builds Cali's system prompt: personality, calendar tool guidance, loaded memory, session context (date/timezone/name), and calendar snapshot.

**When to introduce multi-agent:** Only when a task genuinely requires parallel exploration, exceeds the context window, or involves a distinct new specialist (e.g. an async MemoryAgent, EmailAgent). For sequential calendar CRUD, a single agent with direct tool access is faster, cheaper, and simpler — the orchestrator-subagent pattern adds 2–3× API call overhead with no benefit for this problem size.

## UI & Calendar Behavior

- Use native macOS SwiftUI patterns first: `NavigationSplitView`, `.sidebar` `List`, `SettingsLink`, toolbars, and system controls.
- Keep the left pane as a standard navigation/sidebar list for conversations. Do not put the calendar account list or calendar filter toggles there.
- Keep default calendar selection in Settings unless the product flow is intentionally redesigned.
- The middle calendar surface is read-only. Event creation and updates should stay agent-driven through Cali and `CalendarToolExecutor`.
- Launch should request Calendar permission through EventKit when needed, then load calendars and the displayed week's events.
- Empty weeks should still render the week grid; only denied Calendar access should replace the grid with an unavailable state.
- Calendar UI tests should use fake stores. Do not add default tests that require live Calendar permission.

## Logging

Uses `os.Logger` with subsystem `jian.ai.ical-mac`. Stream live logs:

```bash
log stream --predicate 'subsystem == "jian.ai.ical-mac"' --level debug
```

## Notes

This app does not reuse TypeScript, Bun, Ink, or the `ical-chat` runtime.
