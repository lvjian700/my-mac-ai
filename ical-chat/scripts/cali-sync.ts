#!/usr/bin/env bun
// Background daemon — refreshes ~/.my-mac-ai/ical/session-memory.json every 2 minutes.
// Run alongside cali: `bun run sync` or install via launchd.

import { buildSessionMemory } from "../src/session-memory.js";

const INTERVAL_MS = 2 * 60 * 1000;

function sync() {
  try {
    const memory = buildSessionMemory();
    console.log(`[cali-sync] ${memory.events.length} events synced at ${memory.syncedAt}`);
  } catch (err) {
    console.error(`[cali-sync] sync failed: ${err instanceof Error ? err.message : err}`);
  }
}

sync();
setInterval(sync, INTERVAL_MS);
