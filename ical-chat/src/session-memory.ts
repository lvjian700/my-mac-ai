import { execFileSync } from "child_process";
import { writeFileSync, readFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { homedir } from "os";

// ─── Types ────────────────────────────────────────────────────────────────────

export type CalEvent = {
  id: string;
  title: string;
  date: string;
  dayOfWeek: string;
  start: string;
  end: string;
  time?: { start: string; end: string };
  allDay: boolean;
  calendar: string;
  location?: string;
  notes?: string;
};

export type SessionMemory = {
  events: CalEvent[];
  syncedAt: string;
  range: { from: string; to: string };
};

export type EventDiff = {
  added: CalEvent[];
  changed: { before: CalEvent; after: CalEvent }[];
  removed: CalEvent[];
};

export type SessionMemoryUpdate = {
  kind: "session_memory_update";
  syncedAt: string;
  diff: EventDiff;
};

// ─── Storage ──────────────────────────────────────────────────────────────────

const SESSION_MEMORY_PATH = join(homedir(), ".my-mac-ai/ical/session-memory.json");

export function hotRange(): { from: string; to: string } {
  const toYMD = (d: Date) => d.toLocaleDateString("en-CA");
  const today = new Date();
  const dow = today.getDay(); // 0=Sun, 1=Mon … 6=Sat
  const daysToMonday = dow === 0 ? 6 : dow - 1;
  const monday = new Date(today);
  monday.setDate(today.getDate() - daysToMonday);
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 13); // Mon → next Sun = 13 days
  return { from: toYMD(monday), to: toYMD(sunday) };
}

export function buildSessionMemory(): SessionMemory {
  const range = hotRange();
  const raw = execFileSync(
    "ical",
    ["events", "--from", range.from, "--to", range.to, "--format", "json"],
    { encoding: "utf-8", timeout: 15_000 },
  );
  const memory: SessionMemory = {
    events: JSON.parse(raw) as CalEvent[],
    syncedAt: new Date().toISOString(),
    range,
  };
  mkdirSync(dirname(SESSION_MEMORY_PATH), { recursive: true });
  writeFileSync(SESSION_MEMORY_PATH, JSON.stringify(memory, null, 2), "utf-8");
  return memory;
}

export function readSessionMemory(): SessionMemory | null {
  if (!existsSync(SESSION_MEMORY_PATH)) return null;
  try {
    return JSON.parse(readFileSync(SESSION_MEMORY_PATH, "utf-8")) as SessionMemory;
  } catch {
    return null;
  }
}

// ─── Diff ─────────────────────────────────────────────────────────────────────

export function diffEvents(before: CalEvent[], after: CalEvent[]): EventDiff {
  const beforeMap = new Map(before.map((e) => [e.id, e]));
  const afterMap = new Map(after.map((e) => [e.id, e]));

  const added: CalEvent[] = [];
  const changed: { before: CalEvent; after: CalEvent }[] = [];
  const removed: CalEvent[] = [];

  for (const [id, afterEvent] of afterMap) {
    const beforeEvent = beforeMap.get(id);
    if (!beforeEvent) {
      added.push(afterEvent);
    } else if (
      beforeEvent.title !== afterEvent.title ||
      beforeEvent.start !== afterEvent.start ||
      beforeEvent.end !== afterEvent.end ||
      beforeEvent.location !== afterEvent.location
    ) {
      changed.push({ before: beforeEvent, after: afterEvent });
    }
  }

  for (const [id, beforeEvent] of beforeMap) {
    if (!afterMap.has(id)) removed.push(beforeEvent);
  }

  return { added, changed, removed };
}

export function isDiffEmpty(diff: EventDiff): boolean {
  return diff.added.length === 0 && diff.changed.length === 0 && diff.removed.length === 0;
}

// ─── Formatting ───────────────────────────────────────────────────────────────

function formatEventTime(event: CalEvent): string {
  if (event.allDay) return "all day";
  if (event.time) return `${event.time.start}–${event.time.end}`;
  return "";
}

function formatSnapshotLine(event: CalEvent): string {
  const dow = event.dayOfWeek.slice(0, 3);
  const time = formatEventTime(event).padEnd(11);
  return `${event.date} ${dow}  ${time}  ${event.title} [${event.calendar}]`;
}

export function formatSnapshot(memory: SessionMemory): string {
  const syncTime = new Date(memory.syncedAt).toLocaleTimeString("en-AU", {
    hour: "2-digit",
    minute: "2-digit",
  });
  const fmt = new Intl.DateTimeFormat("en-AU", { month: "short", day: "numeric" });
  const rangeStr = `${fmt.format(new Date(memory.range.from))} – ${fmt.format(new Date(memory.range.to))}`;

  return [
    `## Calendar Snapshot (synced ${syncTime} · ${rangeStr})`,
    ...memory.events.map(formatSnapshotLine),
    "",
    `Events for ${rangeStr} are pre-loaded above. Answer questions about this period directly from the snapshot — do NOT call the calendar tool and do NOT describe what you are doing. Only call the calendar tool for dates outside this range or to create/update/delete events.`,
  ].join("\n");
}

export function formatMemoryUpdate(update: SessionMemoryUpdate): string {
  const syncTime = new Date(update.syncedAt).toLocaleTimeString("en-AU", {
    hour: "2-digit",
    minute: "2-digit",
  });
  const lines: string[] = [`[Calendar update ${syncTime}]`];

  for (const e of update.diff.added) {
    const time = formatEventTime(e);
    lines.push(`+ ${e.title}  ${e.dayOfWeek.slice(0, 3)} ${e.date}${time ? ", " + time : ""} [${e.calendar}]`);
  }

  for (const { before, after } of update.diff.changed) {
    const beforeTime = formatEventTime(before);
    const afterTime = formatEventTime(after);
    if (before.title !== after.title) {
      lines.push(`~ ${before.title} → ${after.title}  ${after.date} [${after.calendar}]`);
    } else if (beforeTime !== afterTime) {
      lines.push(`~ ${after.title}  ${after.date} ${beforeTime} → ${afterTime} [${after.calendar}]`);
    } else {
      lines.push(`~ ${after.title}  ${after.date} changed [${after.calendar}]`);
    }
  }

  for (const e of update.diff.removed) {
    lines.push(`- ${e.title}  ${e.dayOfWeek.slice(0, 3)} ${e.date} removed [${e.calendar}]`);
  }

  return lines.join("\n");
}
