import { describe, expect, test } from "bun:test";
import type { CalEvent, SessionMemory, SessionMemoryUpdate, EventDiff } from "../src/session-memory.js";
import {
  diffEvents,
  isDiffEmpty,
  formatSnapshot,
  formatMemoryUpdate,
} from "../src/session-memory.js";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const TODAY = new Date().toLocaleDateString("en-CA");
const TODAY_DOW = new Date().toLocaleDateString("en-US", { weekday: "long" });
const TODAY_START = `${TODAY}T13:00:00+10:00`;
const TODAY_END = `${TODAY}T13:30:00+10:00`;
const SYNCED_AT = `${TODAY}T03:00:00.000Z`;

function makeEvent(overrides: Partial<CalEvent> = {}): CalEvent {
  return {
    id: "296A9A14-1111:FD2DD2B1-AAAA",
    title: "Dental Appointment",
    date: TODAY,
    dayOfWeek: TODAY_DOW,
    start: TODAY_START,
    end: TODAY_END,
    time: { start: "13:00", end: "13:30" },
    allDay: false,
    calendar: "Jian Lv",
    location: "Bupa Dental Doncaster",
    ...overrides,
  };
}

function makeMemory(overrides: Partial<SessionMemory> = {}): SessionMemory {
  return {
    events: [makeEvent()],
    syncedAt: SYNCED_AT,
    range: { from: TODAY, to: TODAY },
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// diffEvents
// ---------------------------------------------------------------------------

describe("diffEvents", () => {
  test("returns empty diff when both arrays are identical", () => {
    const events = [makeEvent(), makeEvent({ id: "ID-2", title: "Standup" })];
    const diff = diffEvents(events, events);
    expect(diff.added).toHaveLength(0);
    expect(diff.changed).toHaveLength(0);
    expect(diff.removed).toHaveLength(0);
  });

  test("detects added events (present in after but not before)", () => {
    const before: CalEvent[] = [];
    const after = [makeEvent()];
    const diff = diffEvents(before, after);
    expect(diff.added).toHaveLength(1);
    expect(diff.added[0].id).toBe(makeEvent().id);
    expect(diff.changed).toHaveLength(0);
    expect(diff.removed).toHaveLength(0);
  });

  test("detects removed events (present in before but not after)", () => {
    const before = [makeEvent()];
    const after: CalEvent[] = [];
    const diff = diffEvents(before, after);
    expect(diff.removed).toHaveLength(1);
    expect(diff.removed[0].id).toBe(makeEvent().id);
    expect(diff.added).toHaveLength(0);
    expect(diff.changed).toHaveLength(0);
  });

  test("detects changed events when title differs", () => {
    const before = [makeEvent({ title: "Old Title" })];
    const after = [makeEvent({ title: "New Title" })];
    const diff = diffEvents(before, after);
    expect(diff.changed).toHaveLength(1);
    expect(diff.changed[0].before.title).toBe("Old Title");
    expect(diff.changed[0].after.title).toBe("New Title");
    expect(diff.added).toHaveLength(0);
    expect(diff.removed).toHaveLength(0);
  });

  test("detects changed events when start time differs", () => {
    const before = [makeEvent({ start: "2026-05-16T13:00:00+10:00" })];
    const after = [makeEvent({ start: "2026-05-16T14:00:00+10:00" })];
    const diff = diffEvents(before, after);
    expect(diff.changed).toHaveLength(1);
    expect(diff.changed[0].before.start).toBe("2026-05-16T13:00:00+10:00");
    expect(diff.changed[0].after.start).toBe("2026-05-16T14:00:00+10:00");
  });

  test("detects changed events when end time differs", () => {
    const before = [makeEvent({ end: "2026-05-16T13:30:00+10:00" })];
    const after = [makeEvent({ end: "2026-05-16T14:00:00+10:00" })];
    const diff = diffEvents(before, after);
    expect(diff.changed).toHaveLength(1);
  });

  test("detects changed events when location differs", () => {
    const before = [makeEvent({ location: "Old Location" })];
    const after = [makeEvent({ location: "New Location" })];
    const diff = diffEvents(before, after);
    expect(diff.changed).toHaveLength(1);
    expect(diff.changed[0].before.location).toBe("Old Location");
    expect(diff.changed[0].after.location).toBe("New Location");
  });

  test("handles mix of added, changed, and removed events", () => {
    const eventA = makeEvent({ id: "ID-A", title: "Event A" });
    const eventAChanged = makeEvent({ id: "ID-A", title: "Event A Modified" });
    const eventB = makeEvent({ id: "ID-B", title: "Event B" });
    const eventC = makeEvent({ id: "ID-C", title: "Event C" });

    const before = [eventA, eventB];
    const after = [eventAChanged, eventC];

    const diff = diffEvents(before, after);
    expect(diff.added).toHaveLength(1);
    expect(diff.added[0].id).toBe("ID-C");
    expect(diff.changed).toHaveLength(1);
    expect(diff.changed[0].before.id).toBe("ID-A");
    expect(diff.removed).toHaveLength(1);
    expect(diff.removed[0].id).toBe("ID-B");
  });

  test("events with matching id but only calendar changed are NOT flagged as changed", () => {
    // Only title, start, end, location trigger a change — calendar does not
    const before = [makeEvent({ calendar: "Work" })];
    const after = [makeEvent({ calendar: "Personal" })];
    const diff = diffEvents(before, after);
    expect(diff.changed).toHaveLength(0);
    expect(diff.added).toHaveLength(0);
    expect(diff.removed).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// isDiffEmpty
// ---------------------------------------------------------------------------

describe("isDiffEmpty", () => {
  test("returns true when all three arrays are empty", () => {
    const diff: EventDiff = { added: [], changed: [], removed: [] };
    expect(isDiffEmpty(diff)).toBe(true);
  });

  test("returns false when there are added events", () => {
    const diff: EventDiff = { added: [makeEvent()], changed: [], removed: [] };
    expect(isDiffEmpty(diff)).toBe(false);
  });

  test("returns false when there are changed events", () => {
    const e = makeEvent();
    const diff: EventDiff = { added: [], changed: [{ before: e, after: e }], removed: [] };
    expect(isDiffEmpty(diff)).toBe(false);
  });

  test("returns false when there are removed events", () => {
    const diff: EventDiff = { added: [], changed: [], removed: [makeEvent()] };
    expect(isDiffEmpty(diff)).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// formatSnapshot
// ---------------------------------------------------------------------------

describe("formatSnapshot", () => {
  test("starts with the ## Calendar Snapshot header", () => {
    const memory = makeMemory();
    const result = formatSnapshot(memory);
    expect(result).toMatch(/^## Calendar Snapshot \(synced/);
  });

  test("includes synced time derived from syncedAt", () => {
    // syncedAt is 2026-05-16T03:00:00.000Z — exact local time depends on TZ,
    // but the header must contain the HH:MM pattern
    const memory = makeMemory({ syncedAt: "2026-05-16T03:00:00.000Z" });
    const result = formatSnapshot(memory);
    expect(result).toMatch(/synced \d{2}:\d{2}/);
  });

  test("includes each event title in the output", () => {
    const memory = makeMemory({
      events: [
        makeEvent({ title: "Dental Appointment" }),
        makeEvent({ id: "ID-2", title: "Team Standup" }),
      ],
    });
    const result = formatSnapshot(memory);
    expect(result).toContain("Dental Appointment");
    expect(result).toContain("Team Standup");
  });

  test("formats all-day events with 'all day' time label", () => {
    const memory = makeMemory({
      events: [makeEvent({ allDay: true, time: undefined })],
    });
    const result = formatSnapshot(memory);
    expect(result).toContain("all day");
  });

  test("formats timed events with HH:MM–HH:MM time range", () => {
    const memory = makeMemory({
      events: [makeEvent({ allDay: false, time: { start: "13:00", end: "13:30" } })],
    });
    const result = formatSnapshot(memory);
    expect(result).toContain("13:00–13:30");
  });

  test("includes event date and 3-letter day-of-week abbreviation", () => {
    const memory = makeMemory({
      events: [makeEvent({ date: "2026-05-16", dayOfWeek: "Saturday" })],
    });
    const result = formatSnapshot(memory);
    expect(result).toContain("2026-05-16");
    expect(result).toContain("Sat");
  });

  test("includes calendar name in brackets", () => {
    const memory = makeMemory({
      events: [makeEvent({ calendar: "Jian Lv" })],
    });
    const result = formatSnapshot(memory);
    expect(result).toContain("[Jian Lv]");
  });

  test("ends with a pre-loaded notice about date range", () => {
    const memory = makeMemory();
    const result = formatSnapshot(memory);
    expect(result).toContain("are pre-loaded above");
    expect(result).toContain("Only call the calendar tool for dates outside this range");
  });

  test("handles empty event list gracefully", () => {
    const memory = makeMemory({ events: [] });
    const result = formatSnapshot(memory);
    expect(result).toMatch(/^## Calendar Snapshot/);
    expect(result).toContain("are pre-loaded above");
  });
});

// ---------------------------------------------------------------------------
// formatMemoryUpdate
// ---------------------------------------------------------------------------

describe("formatMemoryUpdate", () => {
  function makeUpdate(diff: Partial<EventDiff> = {}): SessionMemoryUpdate {
    return {
      kind: "session_memory_update",
      syncedAt: "2026-05-16T03:00:00.000Z",
      diff: {
        added: [],
        changed: [],
        removed: [],
        ...diff,
      },
    };
  }

  test("starts with [Calendar update HH:MM] header", () => {
    const result = formatMemoryUpdate(makeUpdate());
    // en-AU locale may produce "03:00 am" or "03:00" depending on the runtime
    expect(result).toMatch(/^\[Calendar update \d{2}:\d{2}/);
  });

  test("formats added events with '+' prefix", () => {
    const event = makeEvent({ title: "New Meeting", dayOfWeek: "Monday", date: "2026-05-18" });
    const result = formatMemoryUpdate(makeUpdate({ added: [event] }));
    expect(result).toContain("+ New Meeting");
    expect(result).toContain("Mon");
    expect(result).toContain("2026-05-18");
    expect(result).toContain("[Jian Lv]");
  });

  test("formats added all-day events without time suffix", () => {
    const event = makeEvent({ title: "Conference", allDay: true, time: undefined });
    const result = formatMemoryUpdate(makeUpdate({ added: [event] }));
    const lines = result.split("\n");
    const addedLine = lines.find((l) => l.startsWith("+"));
    expect(addedLine).toBeDefined();
    // No comma+time appended for all-day events
    expect(addedLine).not.toMatch(/,\s*\d{2}:\d{2}/);
  });

  test("formats added timed events with time suffix", () => {
    const event = makeEvent({ title: "Doctor", time: { start: "09:00", end: "10:00" } });
    const result = formatMemoryUpdate(makeUpdate({ added: [event] }));
    expect(result).toContain("09:00–10:00");
  });

  test("formats removed events with '-' prefix and 'removed' label", () => {
    const event = makeEvent({ title: "Cancelled Lunch", dayOfWeek: "Friday", date: "2026-05-22" });
    const result = formatMemoryUpdate(makeUpdate({ removed: [event] }));
    expect(result).toContain("- Cancelled Lunch");
    expect(result).toContain("Fri");
    expect(result).toContain("removed");
  });

  test("formats title-changed events with '~' prefix and arrow", () => {
    const before = makeEvent({ title: "Old Name" });
    const after = makeEvent({ title: "New Name" });
    const result = formatMemoryUpdate(makeUpdate({ changed: [{ before, after }] }));
    expect(result).toContain("~ Old Name → New Name");
  });

  test("formats time-changed events with '~' prefix and time arrow", () => {
    const before = makeEvent({
      title: "Standup",
      time: { start: "09:00", end: "09:30" },
      start: "2026-05-16T09:00:00+10:00",
      end: "2026-05-16T09:30:00+10:00",
    });
    const after = makeEvent({
      title: "Standup",
      time: { start: "10:00", end: "10:30" },
      start: "2026-05-16T10:00:00+10:00",
      end: "2026-05-16T10:30:00+10:00",
    });
    const result = formatMemoryUpdate(makeUpdate({ changed: [{ before, after }] }));
    expect(result).toContain("~");
    expect(result).toContain("09:00–09:30");
    expect(result).toContain("10:00–10:30");
  });

  test("formats generic change with 'changed' label when only location differs", () => {
    const before = makeEvent({ location: "Room A" });
    const after = makeEvent({ location: "Room B" });
    const result = formatMemoryUpdate(makeUpdate({ changed: [{ before, after }] }));
    expect(result).toContain("~ ");
    expect(result).toContain("changed");
  });

  test("handles empty diff with just the header", () => {
    const result = formatMemoryUpdate(makeUpdate());
    const lines = result.split("\n");
    expect(lines).toHaveLength(1);
    expect(lines[0]).toMatch(/^\[Calendar update/);
  });
});
