---
name: ical
description: >
  Read and write Apple Calendar events using the local `ical` CLI.
  TRIGGER when: user asks about their schedule, upcoming events, "what's on my
  calendar", "am I free on ...", "add an event", "create a meeting", "reschedule",
  "move my meeting", "push back the standup", "what do I have going on",
  "how busy am I this week", "block time", "find a free slot", or any
  calendar-related query.
  DO NOT TRIGGER when: user is discussing the ical source code or building the binary.
allowed-tools: Bash(ical *) Bash(date +%Z)
---

# ical - Apple Calendar Skill

Use the `ical` CLI to answer calendar questions.
Always use `--format json` so output is structured.
Always use user's local timezone for date and time. 
Run `date +%Z` to get the local timezone if you don't know.

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
- Repeat `--calendar` to filter multiple calendars

Workflow
- By default, reading events from today to the end of week
- When user mention a date or a range, auto resolve the `--from <date> --to <date>`

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

## Workflow

1. Run the minimal `ical` call that answers the question.
2. Parse JSON and present a clean human-readable summary.
3. If the binary is missing, tell the user to run `make install` inside `ical/`.
