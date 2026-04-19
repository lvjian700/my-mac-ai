# Test ical

Verify all three commands work correctly against a real calendar, and establish a unit test strategy for pure logic.

## Manual checklist

- [ ] `ical list` — lists calendars
- [ ] `ical events` — lists today's events
- [ ] `ical events --from 2026-04-01 --to 2026-04-30` — date range filter
- [ ] `ical events --calendar "Work"` — calendar filter
- [ ] `ical events --format json` — JSON output
- [ ] `ical add "Test event" --start 2026-04-13T10:00:00 --end 2026-04-13T11:00:00` — add event
- [ ] `ical add "All day" --start 2026-04-13 --end 2026-04-14 --all-day` — all-day event
