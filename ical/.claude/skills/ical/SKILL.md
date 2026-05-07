---
name: ical
description: >
  Read and write Apple Calendar events using the local `ical` CLI.
  TRIGGER when: user asks about their schedule, upcoming events, calendar habits,
  calendar memory/rules, "what's on my calendar", "am I free on ...", "add an
  event", "create a meeting", "reschedule", "move my meeting", "push back the
  standup", "what do I have going on", "how busy am I this week", "block time",
  "find a free slot", or any calendar-related query.
  DO NOT TRIGGER when: user is discussing the ical source code or building the binary.
allowed-tools: Bash(ical *) Bash(date +%Z) Bash(scripts/ical-memory)
---

# ical - Apple Calendar Skill

Use the `ical` CLI to answer calendar questions, DO NOT search other place for `ical` binary.
Always use `--format json` so output is structured.
Always use user's local timezone for date and time.

## Display

Highlight time with **bold text**.
Using markdown for output.

## Commands

### List calendars
```sh
ical list --format json
```
Use this first if the user mentions a calendar name you haven't seen before.

### Query events
```sh
ical events --from <date> --to <date> [--calendar <name>] --format json
```
- `<date>`: `today`, `tomorrow`, `YYYY-MM-DD`, or `YYYY-MM-DDThh:mm:ss`
- When `--to` uses a relative day (`today`, `tomorrow`, a named weekday, etc.), resolve it
  to the **last second of that day** (`YYYY-MM-DDT23:59:59`) so all events on that day are included.
- Repeat `--calendar` to filter multiple calendars

Workflow
- By default, read events from today to the end of the current week (Sunday)
- When user mentions a date or a range, auto-resolve `--from`/`--to`

### Add an event
```sh
ical add "<title>" --start <datetime> \
     [--short | --normal | --long | --end <datetime>] \
     [--calendar <name>] [--location <loc>] [--notes <text>] [--all-day] \
     --format json
```
- `--start` required; use ISO-8601 (`2026-04-19T14:00:00`)
- Duration flags (mutually exclusive, take priority over `--end`):
  - `--short` - 15 minutes
  - `--normal` - 30 minutes
  - `--long` - 45 minutes
- `--end` - explicit end datetime; use ISO-8601
- If none provided, defaults to 30 minutes (`--normal` behaviour)

### Update an event
```sh
ical update <event-id> \
     [--title "<new title>"] \
     [--start <datetime>] \
     [--short | --normal | --long | --end <datetime>] \
     [--calendar <name>] [--account <account>] \
     --format json
```
- Get `<event-id>` from `ical events --format json` (the `id` field)
- All options are optional; only provided fields are changed
- `--start` alone (no duration flag): moves the event, preserving its original duration
- Duration flags and `--end` work the same as `add`

### Reference: default calendar config

For uncommon requests to view or set default account/calendar values for future
`ical add` commands, read [references/config.md](references/config.md).

## Memory

At the start of any calendar request, read [references/calendar_rules.md](references/calendar_rules.md)
and run `scripts/ical-memory` to load saved rules.

- **Capture**: when the user describes a calendar habit or preference, save it as a rule.
- **Apply**: after every event query, match events against rules and act.

## Workflow

1. Load memory (see above). Run `date +%Z` to get the local timezone if not already known.
2. Run the minimal `ical` call that answers the question.
3. Match returned events against loaded rules and apply them.
4. Present a clean human-readable summary. Do not explain which rules were applied.
