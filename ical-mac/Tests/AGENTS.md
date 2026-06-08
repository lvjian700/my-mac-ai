# Agent Guide - Tests

Tests use Swift Testing and run through the `ical-mac` Xcode scheme from
`ical-mac/`.

## Rules

- Do not depend on live Apple Calendar permission, real EventKit data, OpenAI
  network calls, or user Keychain state.
- Use fake calendar stores, fake OpenAI clients, fake API key stores, and
  temporary directories.
- Remove temporary directories with `defer` when tests create them.
- Keep UI tests at the view-model, layout, formatting, and presentation-helper
  level unless an explicit UI automation workflow is requested.

## Coverage Expectations

- `ICalMacCoreTests` should cover tool execution, prompt contents, date parsing,
  memory/conversation stores, OpenAI request flow, and assistant transcript
  behavior.
- `ICalMacUITests` should cover `AppModel`, calendar filtering, week layout,
  formatter/presentation helpers, composer behavior, and voice-input controller
  logic.
- When adding or renaming a calendar tool, test the OpenAI/tool loop plus
  executor behavior and update any UI tool-status expectations.
- When changing conversation persistence, test summaries, restore order, delete
  fallback behavior, and transcript persistence.
