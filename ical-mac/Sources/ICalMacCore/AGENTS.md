# Agent Guide - ICalMacCore

Core owns the non-UI behavior for the native app: calendar access, assistant
requests, tool execution, prompt construction, memory, conversations, and
Keychain-backed API key storage.

## Boundaries

- Keep this source area UI-free. Do not import SwiftUI or AppKit here.
- `CalendarStore` is the boundary for calendar operations. Use fakes in tests;
  only `EventKitCalendarStore` should touch EventKit.
- `EventKitCalendarStore` is a `@MainActor` bridge over the internal
  `CalendarActor`; keep EventKit store usage inside that actor to avoid
  Sendable violations.
- `OpenAIClient` targets `https://api.openai.com/v1/responses` and supports
  both non-streaming and SSE streaming responses.
- `AssistantService` owns the multi-turn `inputHistory`, builds the system
  prompt per turn, sends OpenAI requests, appends function calls/results, and
  stops after `maxToolRounds`.

## Calendar Tools

`CalendarToolExecutor.toolDefinitions` is the source of truth for Cali's tool
surface. It currently exposes:

- `list_calendars`
- `list_events`
- `create_event`
- `update_event`
- `delete_event`
- `write_memory`
- `respond_to_invite`

When adding, removing, or renaming a tool, update `CalendarToolExecutor`,
`PromptStore` guidance, UI tool-status text in `AppModel`, and core tests in
the same change.

## Prompt And Memory

- `PromptStore.buildSystemPrompt(...)` is the native app's prompt source.
- The prompt should describe Cali as a native app assistant with direct calendar
  tools. Do not load shared CLI skill text from `ical/`.
- `MemoryStore` reads/writes `~/.my-mac-ai/ical/memory.yaml` and
  `session-memory.json`.
- `write_memory` writes the full YAML memory content. Preserve that contract
  when changing memory behavior.
- Session snapshots are context for the visible week; tools remain required for
  mutations, dates outside the snapshot, and unknown calendars.

## Conversation Storage

- `ConversationStore` is the persistence protocol.
- `JSONConversationStore` writes records under
  `~/.my-mac-ai/ical/conversations`, with `index.json` plus one JSON file per
  conversation.
- `ChatConversationRecord.transcript` stores OpenAI input history separately
  from user-visible `ChatMessage`s. Keep both in sync when changing resume or
  persistence behavior.
- The store should tolerate corrupt conversation files by omitting invalid
  records from summaries.

## API Keys

- `OpenAIAPIKeyStore` uses the macOS Keychain.
- `OPENAI_API_KEY` can bypass Keychain reads in UI flows.
- Tests must use fake key stores and must not touch user Keychain state.
