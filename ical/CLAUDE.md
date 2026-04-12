# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build                    # debug build
swift build -c release         # release binary
swift run ical                 # run with default subcommand (events)
swift run ical list            # list calendars
swift test                     # run tests
```

## Architecture

**Tech stack:** Swift 6 (strict concurrency), EventKit, swift-argument-parser, macOS 14+.

**Data flow:** CLI args → subcommand → `EventKitService` (permission + business logic) → `OutputFormatter` (text/JSON) → stdout.

**Key layers:**

- `IcalCommand.swift` — root command; registers `list`, `events`, `add` subcommands; default is `events`
- `EventKitService.swift` — `@MainActor` singleton wrapping EventKit; handles permission requests, calendar enumeration, event queries, and event creation
- `OutputFormatter.swift` — text table and JSON rendering; `DateParser` handles "today"/"tomorrow" keywords, ISO-8601, and YYYY-MM-DD
- `Commands/Calendar/` — one file per subcommand implementation

**Concurrency:** `EventKitService` is `@MainActor`. Use `@preconcurrency import EventKit` to suppress Swift 6 Sendable warnings from EventKit types. All subcommand `run()` methods must be `async`.

**Permissions:** `Resources/Info.plist` declares `NSCalendarsUsageDescription` and `NSCalendarsFullAccessUsageDescription`; these are bundled via `.process("Resources/Info.plist")` in Package.swift.

## Task Management

Follow the kanban workflow defined in [kanban/CLAUDE.md](kanban/CLAUDE.md) to manage all tasks and features.

## Implementation Status

- `ical list` — fully implemented
- `ical events` — declared in `IcalCommand.swift` but **not yet implemented** (see `kanban/todo/list-events-command.md`)
- `ical add` — declared in `IcalCommand.swift` but **not yet implemented** (see `kanban/todo/add-event-command.md`)

## Notes

- Reminders support is explicitly out of scope (`Commands/Reminders/` is a placeholder only)
