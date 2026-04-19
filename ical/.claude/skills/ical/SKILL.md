---
name: ical
description: >
  Read and write Apple Calendar events using the local `ical` CLI.
  TRIGGER when: user asks about their schedule, upcoming events, "what's on my
  calendar", "am I free on …", "add an event", "create a meeting", or any
  calendar-related query.
  DO NOT TRIGGER when: user is discussing the ical source code or building the binary.
allowed-tools: Bash(ical *),Bash(~/.local/bin/ical *)
---

# ical — Apple Calendar Skill

Use the `ical` binary (installed at `~/.local/bin/ical`) to answer calendar questions.
Always use `--format json` so output is structured.
Alwasy use user's local timezone for date and time.

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
ical add "<title>" --start <datetime> --end <datetime> \
     [--calendar <name>] [--location <loc>] [--notes <text>] [--all-day] \
     --format json
```
- `--start` and `--end` required; use ISO-8601 (`2026-04-19T14:00:00`)

## Workflow

1. Run the minimal `ical` call that answers the question.
2. Parse JSON and present a clean human-readable summary.
3. If the binary is missing, tell the user to run `make install` inside `ical/`.
