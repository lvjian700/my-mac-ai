import Anthropic from "@anthropic-ai/sdk";
import { spawnSync } from "child_process";
import * as os from "os";
import * as path from "path";
import chalk from "chalk";
import { marked } from "marked";
import { markedTerminal } from "marked-terminal";
import { buildSystemPrompt } from "./session.js";
import { tools, executeTool } from "./tools.js";
import { startPrompt, type Prompt } from "./ui.js";

const client = new Anthropic();
const MODEL = "claude-sonnet-4-6";
const STRONG_STYLE = chalk.hex("#cdd6f4").bold;
const EM_STYLE = chalk.hex("#565f89").italic;

// Tokyo Night theme for markdown responses
// eslint-disable-next-line @typescript-eslint/no-explicit-any
marked.use(
  markedTerminal({
    heading: chalk.hex("#7aa2f7").bold,
    firstHeading: chalk.hex("#7aa2f7").bold,
    strong: STRONG_STYLE,
    em: EM_STYLE,
    codespan: chalk.hex("#e0af68"),
    showSectionPrefix: false,
    width: process.stdout.columns ?? 100,
  }) as any,
);

const DIM = "\x1b[2m";
const RST = "\x1b[0m";
const ITALIC = "\x1b[3m";
const IS_DEV = process.env.NODE_ENV !== "production";
const CALI_LABEL = chalk.hex("#bb9af7").bold("Cali");
const userName = process.env.CALI_USER_NAME ?? "You";

function renderToolCall(name: string, args: string[]): string {
  const gray = chalk.gray.bind(chalk);
  const icon = gray("◦");
  const parts: string[] = [icon + " " + gray(name)];
  for (const a of args) {
    parts.push(gray(a));
  }
  return DIM + parts.join(" ") + RST;
}

function renderListInlineMarkdown(line: string): string {
  return line
    .replace(
      /(^|[^*])\*\*((?=\S)(?:[^*\n]*?\S))\*\*/g,
      (_match, prefix: string, text: string) => prefix + STRONG_STYLE(text),
    )
    .replace(
      /(^|[^*])\*((?=\S)(?:[^*\n]*?\S))\*/g,
      (_match, prefix: string, text: string) => prefix + EM_STYLE(text),
    );
}

function renderMarkdown(text: string): string {
  const rendered = String(marked(text));

  // marked-terminal 7.3 leaves inline tokens literal inside tight list items.
  // Patch only rendered list lines so bullets and code/preformatted text stay intact.
  return rendered
    .split("\n")
    .map((line) =>
      /^\s+(?:\*|\d+\.)\s/.test(line) ? renderListInlineMarkdown(line) : line,
    )
    .join("\n");
}

async function runAgentTurn(
  systemPrompt: string,
  history: Anthropic.MessageParam[],
): Promise<void> {
  let totalTools = 0;
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
      // Final turn: render the full buffered text through marked (gives correct
      // multi-block parsing), then append the stats line.
      console.log(renderMarkdown(collectedText).trimEnd());
      const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
      const n = totalTools;
      console.log(
        `${chalk.hex("#9ece6a")("◆")} ${DIM}~${elapsed}s · ${n} tool call${n !== 1 ? "s" : ""}${RST}`,
      );
      break;
    }

    // Intermediate turn: show narration in dim italic, then tool calls.
    const narration = collectedText.trim();
    if (narration) {
      console.log(`${DIM}${ITALIC}${narration}${RST}`);
    }

    if (IS_DEV) {
      for (const call of toolCalls) {
        const input = call.input as Parameters<typeof executeTool>[1];
        const args = Array.isArray(input.args) ? input.args : [];
        console.log(renderToolCall(call.name, args));
      }
    }
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
  console.log("Loading session...");
  const systemPrompt = buildSystemPrompt(userName);
  const history: Anthropic.MessageParam[] = [];

  console.log("ical chat  —  Ctrl-D to exit");

  const prompt = startPrompt(async (input) => {
    const checkpoint = history.length;
    history.push({ role: "user", content: input });
    console.log(`\n${CALI_LABEL}`);

    try {
      await runAgentTurn(systemPrompt, history);
    } catch (err) {
      console.log(`\x1b[31merror: ${err instanceof Error ? err.message : err}\x1b[0m`);
      history.length = checkpoint;
    }
  }, { userName });

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
