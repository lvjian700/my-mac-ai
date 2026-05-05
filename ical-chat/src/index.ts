import Anthropic from "@anthropic-ai/sdk";
import * as readline from "readline";
import chalk from "chalk";
import { marked } from "marked";
import { markedTerminal } from "marked-terminal";
import { buildSystemPrompt } from "./session.js";
import { tools, executeTool } from "./tools.js";

const client = new Anthropic();
const MODEL = "claude-sonnet-4-6";
const STRONG_STYLE = chalk.hex("#cdd6f4").bold;
const EM_STYLE = chalk.hex("#565f89").italic;

// Tokyo Night theme for markdown responses
// eslint-disable-next-line @typescript-eslint/no-explicit-any
marked.use(markedTerminal({
  heading: chalk.hex("#7aa2f7").bold,
  firstHeading: chalk.hex("#7aa2f7").bold,
  strong: STRONG_STYLE,
  em: EM_STYLE,
  codespan: chalk.hex("#e0af68"),
  showSectionPrefix: false,
  width: process.stdout.columns ?? 100,
}) as any);

const DIM = "\x1b[2m";
const RST = "\x1b[0m";
const ITALIC = "\x1b[3m";

const WRITE_OPS = new Set([
  "add",
  "delete",
  "remove",
  "modify",
  "reschedule",
  "update",
  "create",
]);

function renderToolCall(name: string, args: string[]): string {
  const isWrite = name === "ical" && WRITE_OPS.has(args[0] ?? "");
  const icon = isWrite ? chalk.hex("#d2a8ff")("✦") : chalk.dim("⬡");
  const CMD = isWrite ? chalk.hex("#d2a8ff") : chalk.hex("#79c0ff");
  const FLAG = chalk.hex("#a5d6ff");
  const VAL = chalk.hex("#ffa657");

  const parts: string[] = [icon + " " + CMD(name)];
  let i = 0;
  while (i < args.length) {
    const a = args[i];
    if (a.startsWith("--")) {
      parts.push(FLAG(a));
      if (i + 1 < args.length && !args[i + 1].startsWith("--")) {
        parts.push(VAL(args[++i]));
      }
    } else {
      parts.push(CMD(a));
    }
    i++;
  }
  return parts.join(" ");
}

function renderListInlineMarkdown(line: string): string {
  return line
    .replace(
      /(^|[^*])\*\*((?=\S)(?:[^*\n]*?\S))\*\*/g,
      (_match, prefix: string, text: string) => prefix + STRONG_STYLE(text)
    )
    .replace(
      /(^|[^*])\*((?=\S)(?:[^*\n]*?\S))\*/g,
      (_match, prefix: string, text: string) => prefix + EM_STYLE(text)
    );
}

function renderMarkdown(text: string): string {
  const rendered = String(marked(text));

  // marked-terminal 7.3 leaves inline tokens literal inside tight list items.
  // Patch only rendered list lines so bullets and code/preformatted text stay intact.
  return rendered
    .split("\n")
    .map((line) =>
      /^\s+(?:\*|\d+\.)\s/.test(line) ? renderListInlineMarkdown(line) : line
    )
    .join("\n");
}

async function runAgentTurn(
  systemPrompt: string,
  history: Anthropic.MessageParam[]
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

    stream.on("text", (t) => { collectedText += t; });

    const response = await stream.finalMessage();
    history.push({ role: "assistant", content: response.content });

    const toolCalls = response.content.filter(
      (b): b is Anthropic.ToolUseBlock => b.type === "tool_use"
    );

    if (toolCalls.length === 0) {
      // Final turn: render the full buffered text through marked (gives correct
      // multi-block parsing), then append the stats line.
      process.stdout.write(renderMarkdown(collectedText));
      const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
      const n = totalTools;
      process.stdout.write(
        `${chalk.hex("#9ece6a")("◆")} ${DIM}~${elapsed}s · ${n} tool call${n !== 1 ? "s" : ""}${RST}\n`
      );
      break;
    }

    // Intermediate turn: show narration in dim italic, then tool calls.
    const narration = collectedText.trim();
    if (narration) {
      process.stdout.write(`${DIM}${ITALIC}${narration}${RST}\n`);
    }

    for (const call of toolCalls) {
      const input = call.input as Parameters<typeof executeTool>[1];
      const args = Array.isArray(input.args) ? input.args : [];
      process.stdout.write(renderToolCall(call.name, args) + "\n");
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

async function main() {
  process.stdout.write("Loading session...\n");
  const systemPrompt = buildSystemPrompt();

  const history: Anthropic.MessageParam[] = [];

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: process.stdin.isTTY,
  });

  process.stdout.write("ical chat  —  Ctrl-D to exit\n");

  const loop = () => {
    process.stdout.write(`\n${DIM}USER${RST}\n`);
    rl.question(chalk.hex("#9ece6a")("›") + " ", async (line) => {
      const input = line.trim();
      if (!input) {
        loop();
        return;
      }

      const checkpoint = history.length;
      history.push({ role: "user", content: input });

      process.stdout.write(`\n${DIM}AGENT${RST}\n`);

      try {
        await runAgentTurn(systemPrompt, history);
      } catch (err) {
        process.stdout.write(
          `\x1b[31merror: ${err instanceof Error ? err.message : err}\x1b[0m\n`
        );
        history.length = checkpoint;
      }

      loop();
    });
  };

  rl.on("close", () => {
    process.stdout.write("\nBye!\n");
    process.exit(0);
  });

  loop();
}

main();
