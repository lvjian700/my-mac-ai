# Agent Guide - ICalMacApp

This target owns the app entrypoint and macOS app lifecycle wiring.

## Scope

- Keep business logic out of this target. Put calendar, assistant, persistence,
  and UI state changes in `ICalMacCore` or `ICalMacUI`.
- `ICalMacApp` should mostly compose `ContentView`, inject `AppModel`, install
  environment values, configure scenes, and handle app/window lifecycle events.
- Maintain the `.hiddenTitleBar` and unified toolbar style unless the window
  design is intentionally changed.

## Launch And Notifications

- The main window starts `model.loadCalendarOnLaunch()` in `.task`.
- App-active and `EKEventStoreChanged` notifications should route through
  `AppModel.handleStoreChanged()` so calendar refreshes stay debounced.
- Text-size changes should update the `readingTextMetrics` environment via
  `preferredReadingTextMetrics()`.

## App Behavior

- `AppDelegate` sets regular activation and disables automatic window tabbing.
- Keep menu commands minimal and route actions through `AppModel`.
- Settings are provided by the app scene and should receive the same shared
  `AppModel` and text metrics as the main window.
