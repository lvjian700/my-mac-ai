import Anthropic from "@anthropic-ai/sdk";
import { spawnSync } from "child_process";
import * as os from "os";
import * as path from "path";
import chalk from "chalk";
import { buildSystemPrompt } from "./session.js";
import { tools, executeTool } from "./tools.js";
import { startPrompt, type Prompt } from "./ui.js";
import { printWelcome } from "./welcome.js";
import {
  renderConversationBody,
  renderConversationHeader,
  renderConversationMessage,
} from "./renderer.js";
import { CALI } from "./personalities/cali.js";

const DIM = "\x1b[2m";
const RST = "\x1b[0m";
const ITALIC = "\x1b[3m";
const client = new Anthropic();
const MODEL = "claude-sonnet-4-6";
const personality = CALI;
const DEFAULT_USER_NAME = "You";
const userName = process.env.CALI_USER_NAME ?? DEFAULT_USER_NAME;

function renderToolStatus(hasHeader: boolean): boolean {
  if (!hasHeader) {
    console.log();
    console.log(
      renderConversationHeader(
        personality.name,
        "assistant",
        new Date(),
        personality,
      ),
    );
  }

  process.stdout.write(chalk.hex("#333")("  · checking your calendar...\n"));
  return true;
}

async function runAgentTurn(
  systemPrompt: string,
  history: Anthropic.MessageParam[],
): Promise<void> {
  let totalTools = 0;
  let hasAssistantHeader = false;
  const t0 = Date.now();

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
      if (hasAssistantHeader) {
        console.log(renderConversationBody(collectedText, personality));
      } else {
        console.log();
        console.log(
          renderConversationMessage(
            {
              speaker: personality.name,
              body: collectedText,
              kind: "assistant",
              timestamp: new Date(),
            },
            personality,
          ),
        );
      }
      const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
      const n = totalTools;
      console.log(
        chalk.hex("#333")(
          `  ◆ ~${elapsed}s · ${n} tool call${n !== 1 ? "s" : ""}`,
        ),
      );
      break;
    }

    // Intermediate turn: show narration in dim italic, then tool calls.
    const narration = collectedText.trim();
    if (narration) {
      console.log(`${DIM}${ITALIC}${narration}${RST}`);
    }

    hasAssistantHeader = renderToolStatus(hasAssistantHeader);
    totalTools += toolCalls.length;

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

  const prompt = startPrompt(async (input) => {
    const checkpoint = history.length;
    history.push({ role: "user", content: input });

    try {
      await runAgentTurn(systemPrompt, history);
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
