import Anthropic from "@anthropic-ai/sdk";
import { spawnSync } from "child_process";
import * as os from "os";
import * as path from "path";
import { buildSystemPrompt } from "./session.js";
import { tools, executeTool } from "./tools.js";
import {
  startPrompt,
  type AssistantResponseUpdater,
  type Prompt,
} from "./ui.js";
import { printWelcome } from "./welcome.js";
import { CALI } from "./personalities/cali.js";

const DIM = "\x1b[2m";
const RST = "\x1b[0m";
const client = new Anthropic();
const MODEL = "claude-sonnet-4-6";
const personality = CALI;
const DEFAULT_USER_NAME = "You";
const userName = process.env.CALI_USER_NAME ?? DEFAULT_USER_NAME;

async function runAgentTurn(
  systemPrompt: string,
  history: Anthropic.MessageParam[],
  updateAssistantResponse: AssistantResponseUpdater,
): Promise<string> {
  while (true) {
    let collectedText = "";

    const stream = client.messages.stream({
      model: MODEL,
      max_tokens: 4096,
      system: [
        {
          type: "text",
          text: systemPrompt,
          cache_control: { type: "ephemeral" },
        },
      ],
      tools,
      messages: history,
    });

    stream.on("text", (t) => {
      collectedText += t;
    });

    const response = await stream.finalMessage();
    history.push({ role: "assistant", content: response.content });

    const toolCalls = response.content.filter(
      (b): b is Anthropic.ToolUseBlock => b.type === "tool_use",
    );

    if (toolCalls.length === 0) {
      return collectedText;
    }

    // Intermediate turn: show narration as Cali, then run tool calls.
    const narration = collectedText.trim();
    if (narration) {
      updateAssistantResponse({
        state: "presenting",
        body: narration,
        timestamp: new Date(),
      });
    }

    const results: Anthropic.ToolResultBlockParam[] = toolCalls.map((call) => {
      const input = call.input as Parameters<typeof executeTool>[1];
      return {
        type: "tool_result" as const,
        tool_use_id: call.id,
        content: executeTool(call.name, input),
      };
    });

    history.push({ role: "user", content: results });
  }
}

function openInEditor(filePath: string, prompt: Prompt): void {
  const editor = process.env.EDITOR || process.env.VISUAL || "vi";
  prompt.pause();
  spawnSync(editor, [filePath], { stdio: "inherit" });
  prompt.resume();
}

async function main() {
  const systemPrompt = buildSystemPrompt(userName, personality);
  const history: Anthropic.MessageParam[] = [];

  printWelcome();

  const prompt = startPrompt(async (input, updateAssistantResponse) => {
    const checkpoint = history.length;
    history.push({ role: "user", content: input });

    try {
      return await runAgentTurn(
        systemPrompt,
        history,
        updateAssistantResponse,
      );
    } catch (err) {
      console.log(`\x1b[31merror: ${err instanceof Error ? err.message : err}\x1b[0m`);
      history.length = checkpoint;
    }
  }, { userName, personality });

  prompt.registerSlashCommand({
    name: "clear",
    description: "Clear session history",
    action: () => {
      history.length = 0;
      console.log(`${DIM}Session cleared.${RST}`);
    },
  });

  prompt.registerSlashCommand({
    name: "memory",
    description: "Edit calendar memory",
    shortcut: { ctrl: true, name: "e" },
    action: () => {
      const memoryPath = path.join(
        os.homedir(),
        ".my-mac-ai/ical/memory.yaml",
      );
      openInEditor(memoryPath, prompt);
    },
  });

  const exit = () => {
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

main();
