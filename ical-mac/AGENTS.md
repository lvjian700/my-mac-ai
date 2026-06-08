# Agent Guide - ical-mac

Native macOS calendar assistant built as a checked-in Xcode macOS application
project with SwiftUI, EventKit, Keychain storage, and the OpenAI Responses API.

The production code is compiled by the single `ical-mac` application target.
Nested `AGENTS.md` files provide source-area guidance:

| Path | Scope |
|------|-------|
| `Sources/ICalMacCore/AGENTS.md` | Calendar models, EventKit bridge, OpenAI client/tool loop, prompt, memory, Keychain, conversation JSON storage |
| `Sources/ICalMacUI/AGENTS.md` | `AppModel`, SwiftUI views, settings, chat, conversation sidebar, read-only week calendar |
| `Sources/ICalMacApp/AGENTS.md` | App entrypoint, scenes, window/app lifecycle, app-wide environment values |
| `Tests/AGENTS.md` | Unit test patterns and fake-store rules |

## Build, Test, Run

Run commands from `ical-mac/`.

```bash
xcodebuild -project ical-mac.xcodeproj -scheme ical-mac -destination 'platform=macOS' build
make build               # release Xcode build
make test                # Xcode test bundle
make app                 # build and copy .build/ical-mac.app
./scripts/build_app_bundle.sh
make dmg                 # create dist/ical-mac-<version>.dmg for personal use
make install             # install app to ~/Applications/ical-mac.app
```

Requires macOS 14+.

Run `make build` and `make test` after completing a task. For UI/runtime
inspection, prefer `make run`, `make app`, or `./script/build_and_run.sh`.

`make dmg` defaults to ad-hoc signing for personal-use DMGs. For a public
Developer ID release, run it with `REQUIRE_DEVELOPER_ID_DMG=1` and a
`CODESIGN_IDENTITY="Developer ID Application: ..."` value.

## Xcode

```bash
make xcode        # open ical-mac.xcodeproj
make xcode-build  # validate the native ical-mac app scheme
make xcode-test   # run the native Xcode test bundle
```

`ical-mac.xcodeproj` is the canonical project. Do not reintroduce a SwiftPM
package unless the product direction changes.

## Architecture

**Source areas:**

- `ICalMacCore`: calendar domain models, `CalendarStore`, EventKit access,
  OpenAI request/streaming types, `AssistantService`, `CalendarToolExecutor`,
  `PromptStore`, `MemoryStore`, `ConversationStore`, and Keychain access.
- `ICalMacUI`: `AppModel`, SwiftUI screens/components, settings, voice input,
  previews, and presentation helpers.
- `ICalMacApp`: `@main` app, app delegate, main window, settings scene, app
  commands, launch refresh, and global reading text metrics.

This app does not reuse TypeScript, Bun, Ink, Anthropic SDK code, or the
`ical-chat` runtime. Do not import old CLI skill or prompt text from `ical/` or
`ical-chat/`; the native app prompt lives in `PromptStore`.

## Shared Rules

- Keep tests isolated from real Calendar data, live OpenAI calls, and user
  Keychain state. Use fakes and temporary directories.
- Calendar mutations are agent-driven through `CalendarToolExecutor`; the week
  calendar UI remains read-only unless the product flow is intentionally
  redesigned.
- User data lives under `~/.my-mac-ai/ical`: `memory.yaml`,
  `session-memory.json`, and `conversations/`. Do not bake user-specific data
  into tests or previews.
- Keep API keys in `OPENAI_API_KEY` or Keychain via `OpenAIAPIKeyStore`. Never
  commit API keys.
- If git commands fail because `/Users/jlyu/.gitconfig` is unreadable, retry
  with `GIT_CONFIG_GLOBAL=/dev/null`.

## Logging

Most app logs use `os.Logger`. Useful streams:

```bash
log stream --predicate 'subsystem == "jian.ai.ical-mac"' --level debug
log stream --predicate 'subsystem == "com.jlyu.ical-mac"' --level debug
```
