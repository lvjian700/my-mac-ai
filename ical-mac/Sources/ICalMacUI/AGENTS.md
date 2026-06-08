# Agent Guide - ICalMacUI

UI owns `AppModel`, SwiftUI views, settings, previews, voice input, chat, the
conversation sidebar, and the read-only week calendar surface.

## State And Flow

- `AppModel` is `@MainActor` and is the integration point between UI and core
  services.
- Launch flow: load conversations, check/request Calendar access, load
  calendars, build a week snapshot, write the snapshot cache, then display
  visible events.
- Chat flow: ensure a conversation is loaded, append the user message, persist,
  stream assistant tokens, show tool status, persist the final transcript, then
  refresh the calendar.
- Rebuild `AssistantService` after model/default-calendar settings changes and
  preserve the current conversation transcript.
- Auto-refresh runs on a timer and is also debounced from EventKit/app-active
  change notifications.

## Layout

- Use native macOS SwiftUI patterns: `NavigationSplitView`, sidebar `List`,
  `SettingsLink`, toolbars, menus, toggles, and system controls.
- Preserve the three-column product shape:
  conversation history sidebar, chat column, read-only week calendar detail.
- Keep default calendar selection in Settings unless the product flow is
  deliberately redesigned.
- Keep calendar account filters with the calendar header/detail experience, not
  as replacements for the conversation sidebar.
- Empty weeks should still render the week grid. Only denied Calendar access
  should replace the grid with `CalendarUnavailableView`.

## Calendar UI

- Event creation, updates, deletion, and invitation responses should happen
  through Cali and `CalendarToolExecutor`, not direct calendar controls in the
  week view.
- `TimedEventWeekLayout` owns overlapping timed-event geometry. Add layout
  tests for changes to lane assignment, clipping, or multi-day behavior.
- Use `ReadingTextMetrics` for sizes that need to scale with macOS
  Accessibility > Display > Text Size.
- Keep calendar event category, invitation status, relative time, and detail
  formatting in support types so views remain mostly composition.

## Previews

- Previews should use `PreviewCalendarStore`, `PreviewOpenAIClient`,
  `PreviewAPIKeyStore`, and `PreviewConversationStore`.
- Do not let previews call live Calendar, OpenAI, or Keychain APIs.
- Add preview states for loading, denied access, long text, overlapping events,
  and empty data when changing those surfaces.
