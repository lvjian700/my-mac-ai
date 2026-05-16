import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import {
  existsSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  copyFileSync,
  unlinkSync,
} from "fs";
import { join } from "path";
import { homedir } from "os";
import type { CalEvent, SessionMemory } from "../src/session-memory.js";
import {
  readSessionMemory,
  buildSessionMemory,
} from "../src/session-memory.js";

const SESSION_MEMORY_PATH = join(homedir(), ".my-mac-ai/ical/session-memory.json");
const SESSION_MEMORY_DIR = join(homedir(), ".my-mac-ai/ical");

function makeEvent(overrides: Partial<CalEvent> = {}): CalEvent {
  return {
    id: "296A9A14-1111:FD2DD2B1-AAAA",
    title: "Dental Appointment",
    date: "2026-05-16",
    dayOfWeek: "Saturday",
    start: "2026-05-16T13:00:00+10:00",
    end: "2026-05-16T13:30:00+10:00",
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
    syncedAt: "2026-05-16T03:00:00.000Z",
    range: { from: "2026-05-09", to: "2026-05-30" },
    ...overrides,
  };
}

function backupSessionMemory(suffix: string): () => void {
  const backupPath = `${SESSION_MEMORY_PATH}.${suffix}`;

  if (existsSync(SESSION_MEMORY_PATH)) {
    copyFileSync(SESSION_MEMORY_PATH, backupPath);
    return () => {
      copyFileSync(backupPath, SESSION_MEMORY_PATH);
      unlinkSync(backupPath);
    };
  }

  return () => {
    if (existsSync(SESSION_MEMORY_PATH)) unlinkSync(SESSION_MEMORY_PATH);
  };
}

describe("readSessionMemory (integration)", () => {
  let restoreSessionMemory: (() => void) | null = null;

  beforeEach(() => {
    restoreSessionMemory = backupSessionMemory("bak-test");
  });

  afterEach(() => {
    restoreSessionMemory?.();
    restoreSessionMemory = null;
  });

  test("returns null when session-memory.json does not exist", () => {
    if (existsSync(SESSION_MEMORY_PATH)) unlinkSync(SESSION_MEMORY_PATH);
    const result = readSessionMemory();
    expect(result).toBeNull();
  });

  test("returns null when session-memory.json contains invalid JSON", () => {
    mkdirSync(SESSION_MEMORY_DIR, { recursive: true });
    writeFileSync(SESSION_MEMORY_PATH, "NOT_VALID_JSON", "utf-8");
    const result = readSessionMemory();
    expect(result).toBeNull();
  });

  test("returns SessionMemory when file contains valid JSON", () => {
    const memory = makeMemory();
    mkdirSync(SESSION_MEMORY_DIR, { recursive: true });
    writeFileSync(SESSION_MEMORY_PATH, JSON.stringify(memory), "utf-8");

    const result = readSessionMemory();
    expect(result).not.toBeNull();
    expect(result!.range).toEqual(memory.range);
    expect(result!.events).toHaveLength(1);
    expect(result!.events[0].title).toBe("Dental Appointment");
  });

  test("returns null for an empty file", () => {
    mkdirSync(SESSION_MEMORY_DIR, { recursive: true });
    writeFileSync(SESSION_MEMORY_PATH, "", "utf-8");
    const result = readSessionMemory();
    expect(result).toBeNull();
  });
});

describe("buildSessionMemory (integration)", () => {
  let restoreSessionMemory: (() => void) | null = null;

  beforeEach(() => {
    restoreSessionMemory = backupSessionMemory("bak-integration");
  });

  afterEach(() => {
    restoreSessionMemory?.();
    restoreSessionMemory = null;
  });

  test("returns a SessionMemory object with the correct shape", () => {
    const memory = buildSessionMemory();

    expect(memory).toHaveProperty("events");
    expect(memory).toHaveProperty("syncedAt");
    expect(memory).toHaveProperty("range");
    expect(Array.isArray(memory.events)).toBe(true);
    expect(typeof memory.syncedAt).toBe("string");
    expect(typeof memory.range.from).toBe("string");
    expect(typeof memory.range.to).toBe("string");
  });

  test("syncedAt is a valid ISO date string close to now", () => {
    const memory = buildSessionMemory();

    const syncedAt = new Date(memory.syncedAt);
    expect(isNaN(syncedAt.getTime())).toBe(false);
    const diff = Math.abs(Date.now() - syncedAt.getTime());
    expect(diff).toBeLessThan(30_000);
  });

  test("range spans current week Monday to next week Sunday (14 days)", () => {
    const memory = buildSessionMemory();

    const from = new Date(memory.range.from);
    const to = new Date(memory.range.to);

    expect(from.getDay()).toBe(1);
    expect(to.getDay()).toBe(0);
    const spanDays = Math.round((to.getTime() - from.getTime()) / (1000 * 60 * 60 * 24));
    expect(spanDays).toBe(13);

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const fromDiff = Math.round((today.getTime() - from.getTime()) / (1000 * 60 * 60 * 24));
    expect(fromDiff).toBeGreaterThanOrEqual(0);
    expect(fromDiff).toBeLessThanOrEqual(6);
  });

  test("writes session-memory.json to the configured path", () => {
    buildSessionMemory();

    expect(existsSync(SESSION_MEMORY_PATH)).toBe(true);

    const written = JSON.parse(readFileSync(SESSION_MEMORY_PATH, "utf-8")) as SessionMemory;
    expect(written).toHaveProperty("events");
    expect(written).toHaveProperty("syncedAt");
    expect(written).toHaveProperty("range");
  });

  test("written file content matches the returned SessionMemory object", () => {
    const returned = buildSessionMemory();
    const written = JSON.parse(readFileSync(SESSION_MEMORY_PATH, "utf-8")) as SessionMemory;

    expect(written.syncedAt).toBe(returned.syncedAt);
    expect(written.range).toEqual(returned.range);
    expect(written.events).toEqual(returned.events);
  });

  test("events array contains CalEvent objects with required fields", () => {
    const memory = buildSessionMemory();

    for (const event of memory.events) {
      expect(typeof event.id).toBe("string");
      expect(event.id.length).toBeGreaterThan(0);
      expect(typeof event.title).toBe("string");
      expect(typeof event.date).toBe("string");
      expect(typeof event.dayOfWeek).toBe("string");
      expect(typeof event.start).toBe("string");
      expect(typeof event.end).toBe("string");
      expect(typeof event.allDay).toBe("boolean");
      expect(typeof event.calendar).toBe("string");
    }
  });

  test("successive calls both write valid JSON and return consistent range", () => {
    const first = buildSessionMemory();
    const second = buildSessionMemory();

    expect(first.range).toEqual(second.range);
    expect(Array.isArray(second.events)).toBe(true);
  });

  test("written JSON is pretty-printed (contains newlines and spaces)", () => {
    buildSessionMemory();
    const raw = readFileSync(SESSION_MEMORY_PATH, "utf-8");
    expect(raw).toContain("\n");
    expect(raw).toContain("  ");
  });
});
