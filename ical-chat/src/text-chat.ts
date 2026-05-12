import { spawnSync } from "child_process";
import * as os from "os";
import * as path from "path";
import { buildSystemPrompt } from "./session.js";
import {
  RealtimeSession,
  realtimeConfigFromEnv,
  requireOpenAIKey,
} from "./realtime/session.js";
import {
  startPrompt,
  type AssistantResponseUpdater,
  type Prompt,
} from "./ui.js";
import { printWelcome } from "./welcome.js";
import { CALI } from "./personalities/cali.js";

const DIM = "\x1b[2m";
const RST = "\x1b[0m";
const personality = CALI;
const DEFAULT_USER_NAME = "You";

export async function runTextChat() {
  const userName = process.env.CALI_USER_NAME ?? DEFAULT_USER_NAME;
  const systemPrompt = buildSystemPrompt(userName, personality);
  const realtimeConfig = realtimeConfigFromEnv();
  const apiKey = requireOpenAIKey();
  const createSession = () =>
    RealtimeSession.connect({
      apiKey,
      instructions: systemPrompt,
      outputMode: "text",
      ...realtimeConfig,
    });
  let session = createSession();

  printWelcome();

  const prompt = startPrompt(async (input, updateAssistantResponse) => {
    try {
      return await runAgentTurn(session, input, updateAssistantResponse);
    } catch (err) {
      console.log(`\x1b[31merror: ${err instanceof Error ? err.message : err}\x1b[0m`);
    }
  }, { userName, personality });

  prompt.registerSlashCommand({
    name: "clear",
    description: "Clear session history",
    action: () => {
      session.close();
      session = createSession();
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
  session: RealtimeSession,
  input: string,
  updateAssistantResponse: AssistantResponseUpdater,
): Promise<string> {
  return session.sendText(input).then((text) => {
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
