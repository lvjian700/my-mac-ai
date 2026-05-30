# Agent Guide - ical-mac

Native macOS calendar assistant. Built from scratch in SwiftUI with direct EventKit calendar access and a Swift Anthropic Messages API client.

## Build & Run

```bash
swift build              # debug build
swift build -c release   # release build
swift test               # unit tests with fakes
./script/build_and_run.sh # build .app bundle and launch it
make app                 # create .build/ical-mac.app
make install             # install app to ~/Applications/ical-mac.app
```

Requires macOS 14+.

Prefer `./script/build_and_run.sh` or `make app` for local UI inspection. Do not
use the raw SwiftPM executable as the normal GUI run path; the app should launch
as a macOS `.app` bundle so window activation and Calendar permission behavior
match user runs.

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

### Agent Flow (tool-as-agent pattern)

The app uses a two-level sub-agent architecture. Both agents share the same `OpenAIClient` and are wired together inside `AssistantService`.

```
User message
  └─► AssistantService  (ChatAgent — Cali persona)
        ├─ tool: calendar_agent(task)  ──► CalendarAgent
        │                                   ├─ tool: list_calendars
        │                                   ├─ tool: list_events
        │                                   ├─ tool: create_event
        │                                   ├─ tool: update_event
        │                                   └─ tool: write_memory
        │                                   └─ returns result text
        └─ synthesises result → user response
```

**`AssistantService`** (`Services/AssistantService.swift`) — ChatAgent wrapper. Maintains multi-turn `inputHistory`. Exposes a single `calendar_agent` tool to the model; all calendar work is delegated through it. Creates `CalendarAgent` internally during init.

**`CalendarAgent`** (`Services/CalendarAgent.swift`) — Calendar specialist. Stateless (fresh history per call). Receives a task description, runs its own tool loop with all five calendar tools via `CalendarToolExecutor`, and returns plain-text result.

**`PromptStore`** (`Stores/PromptStore.swift`) — Two prompts:
- `buildSystemPrompt(...)` — Cali personality + orchestration guidance (tells ChatAgent to delegate via `calendar_agent`).
- `buildCalendarAgentPrompt(task:snapshot:configuration:)` — Calendar-expert persona; task-focused; no personality.

Adding a new specialist agent follows the same pattern: create a `*Agent.swift` class with its own tool loop, add a tool definition to `AssistantService`, and add a prompt builder to `PromptStore`.

## UI & Calendar Behavior

- Use native macOS SwiftUI patterns first: `NavigationSplitView`, `.sidebar` `List`, `SettingsLink`, toolbars, and system controls.
- Keep the left pane as a standard navigation/sidebar list for conversations. Do not put the calendar account list or calendar filter toggles there.
- Keep default calendar selection in Settings unless the product flow is intentionally redesigned.
- The middle calendar surface is read-only. Event creation and updates should stay agent-driven through Cali and `CalendarToolExecutor`.
- Launch should request Calendar permission through EventKit when needed, then load calendars and the displayed week's events.
- Empty weeks should still render the week grid; only denied Calendar access should replace the grid with an unavailable state.
- Calendar UI tests should use fake stores. Do not add default tests that require live Calendar permission.

## Notes

This app does not reuse TypeScript, Bun, Ink, or the `ical-chat` runtime.
