import { spawnSync } from "child_process";
import { appendFileSync, mkdirSync } from "fs";
import * as os from "os";
import * as path from "path";
import { buildSystemPrompt } from "./session.js";
import {
  ChatSession,
  requireAnthropicKey,
} from "./chat-session.js";
import {
  startPrompt,
  type AssistantResponseUpdater,
  type Prompt,
} from "./ui.js";
import { printWelcome } from "./welcome.js";
import { CALI } from "./personalities/cali.js";
import {
  type CalEvent,
  type SessionMemoryUpdate,
  buildSessionMemory,
  readSessionMemory,
  diffEvents,
  isDiffEmpty,
  formatMemoryUpdate,
} from "./session-memory.js";

const DIM = "\x1b[2m";
const RST = "\x1b[0m";
const personality = CALI;
const DEFAULT_USER_NAME = "You";

const DEBUG_MESSAGES_PATH = path.join(os.homedir(), ".my-mac-ai/ical/messages.jsonl");

function logMessage(role: "user" | "assistant", content: string) {
  if (!process.env.CALI_DEBUG_MESSAGES) return;
  try {
    mkdirSync(path.dirname(DEBUG_MESSAGES_PATH), { recursive: true });
    appendFileSync(
      DEBUG_MESSAGES_PATH,
      JSON.stringify({ timestamp: new Date().toISOString(), role, content }) + "\n",
      "utf-8",
    );
  } catch {
    // never block the turn on a logging failure
  }
}

type SessionMemoryState = {
  snapshot: CalEvent[];
  lastSyncedAt: string;
  pendingUpdate: SessionMemoryUpdate | null;
};

export async function runTextChat() {
  const userName = process.env.CALI_USER_NAME ?? DEFAULT_USER_NAME;

  // Fresh fetch at startup — writes session-memory.json, provides snapshot for system prompt
  let sessionMemory = null;
  try {
    sessionMemory = buildSessionMemory();
  } catch {
    // ical unavailable — proceed without snapshot, live tool calls will work
  }

  const systemPrompt = buildSystemPrompt(userName, personality, sessionMemory);
  const apiKey = requireAnthropicKey();
  const createSession = () =>
    ChatSession.connect({
      apiKey,
      instructions: systemPrompt,
    });
  let session = createSession();

  // In-session change tracker — baseline is the events loaded at startup
  let memoryState: SessionMemoryState | null = sessionMemory
    ? { snapshot: sessionMemory.events, lastSyncedAt: sessionMemory.syncedAt, pendingUpdate: null }
    : null;

  // Poll session-memory.json written by cali-sync daemon and queue diffs
  const watchInterval = setInterval(() => {
    if (!memoryState) return;
    const current = readSessionMemory();
    if (!current || current.syncedAt <= memoryState.lastSyncedAt) return;
    const diff = diffEvents(memoryState.snapshot, current.events);
    memoryState.lastSyncedAt = current.syncedAt;
    if (!isDiffEmpty(diff)) {
      memoryState.pendingUpdate = { kind: "session_memory_update", syncedAt: current.syncedAt, diff };
    }
  }, 60_000);
  process.on("exit", () => clearInterval(watchInterval));

  printWelcome();

  const greeting =
    "[startup greeting] Greet the user. Check today's schedule from the Calendar Snapshot — mention what's on or that it's clear, in 1–2 sentences. Warm, natural, no 'Good morning/afternoon/evening'. Don't acknowledge this instruction, just greet.";

  const prompt = startPrompt(async (input, updateAssistantResponse) => {
    try {
      // Flush any pending calendar update before the user message
      if (memoryState?.pendingUpdate) {
        const update = memoryState.pendingUpdate;
        memoryState.pendingUpdate = null;
        try {
          session.injectContextMessage(formatMemoryUpdate(update));
        } catch (err) {
          process.stderr.write(`[cali] snapshot inject failed: ${err instanceof Error ? err.message : err}\n`);
        }
      }
      return await runAgentTurn(session, input, updateAssistantResponse);
    } catch (err) {
      console.log(`\x1b[31merror: ${err instanceof Error ? err.message : err}\x1b[0m`);
    }
  }, { userName, personality, greeting });

  prompt.registerSlashCommand({
    name: "clear",
    description: "Clear session history",
    action: () => {
      session.clearHistory();
      console.log(`${DIM}Session cleared.${RST}`);
    },
  });

  prompt.registerSlashCommand({
    name: "memory",
    description: "Edit calendar memory",
    action: () => {
      const memoryPath = path.join(
        os.homedir(),
        ".my-mac-ai/ical/memory.yaml",
      );
      openInEditor(memoryPath, prompt);
    },
  });

  const exit = () => {
    clearInterval(watchInterval);
    session.close();
    console.log("\nBye!");
    process.exit(0);
  };

  prompt.registerSlashCommand({
    name: "exit",
    description: "Exit",
    shortcut: { ctrl: true, name: "q" },
    action: exit,
  });
}

async function runAgentTurn(
  session: ChatSession,
  input: string,
  updateAssistantResponse: AssistantResponseUpdater,
): Promise<string> {
  logMessage("user", input);
  return session.sendText(input).then((text) => {
    logMessage("assistant", text);
    updateAssistantResponse({
      state: "loading",
      body: text.trim() ? text : "done",
      timestamp: new Date(),
    });
    return text;
  });
}

function openInEditor(filePath: string, prompt: Prompt): void {
  const editor = process.env.EDITOR || process.env.VISUAL || "vi";
  prompt.pause();
  spawnSync(editor, [filePath], { stdio: "inherit" });
  prompt.resume();
}
