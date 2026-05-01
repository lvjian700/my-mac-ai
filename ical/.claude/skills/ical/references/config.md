# Default Calendar Config

Use this reference only when the user wants to view or set default account/calendar values for future `ical add` commands.

Common use cases:

- Advanced users explicitly ask to change the default account/calendar.
- Events are being created in a local calendar, but the user wants future events to sync through an iCloud account.

## Commands

```sh
ical config
ical config add
ical config add --account <account> --calendar <calendar>
ical config add --user --account <account> --calendar <calendar>
```

- `ical config` - show user, local, and effective config.
- `ical config add` - show the effective config used by `ical add`.
- `ical config add --account ... --calendar ...` - set local defaults in `./.ical/config.json`.
- `ical config add --user --account ... --calendar ...` - set user defaults in `~/.my-mac-ai/ical/config.json`.
- Explicit `ical add --account` or `--calendar` options override configured defaults.

## iCloud sync default

When a user says new events are appearing only locally or not syncing to iCloud:

1. Run `ical list --format json` to find the exact iCloud account and calendar names.
2. Run `ical config add --user --account <icloud-account> --calendar <calendar>` to make future `ical add` commands use that iCloud calendar globally.
3. Use local config instead, without `--user`, only when the default should apply to the current project/directory.
4. For one-off events, prefer explicit `ical add --account <account> --calendar <calendar>` instead of changing defaults.
