import Anthropic from "@anthropic-ai/sdk";
import chalk from "chalk";
import { marked } from "marked";
import { markedTerminal } from "marked-terminal";
import { buildSystemPrompt } from "./session.js";
import { tools, executeTool } from "./tools.js";
import { startPrompt } from "./prompt.js";

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
      process.stdout.write(renderMarkdown(collectedText));
      const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
      const n = totalTools;
      process.stdout.write(
        `${chalk.hex("#9ece6a")("◆")} ${DIM}~${elapsed}s · ${n} tool call${n !== 1 ? "s" : ""}${RST}\n`,
      );
      break;
    }

    // Intermediate turn: show narration in dim italic, then tool calls.
    const narration = collectedText.trim();
    if (narration) {
      process.stdout.write(`${DIM}${ITALIC}${narration}${RST}\n`);
    }

    if (IS_DEV) {
      for (const call of toolCalls) {
        const input = call.input as Parameters<typeof executeTool>[1];
        const args = Array.isArray(input.args) ? input.args : [];
        process.stdout.write(renderToolCall(call.name, args) + "\n");
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

async function main() {
  process.stdout.write("Loading session...\n");
  const systemPrompt = buildSystemPrompt();
  const history: Anthropic.MessageParam[] = [];

  process.stdout.write("ical chat  —  Ctrl-D to exit\n");

  const prompt = startPrompt(async (input) => {
    const checkpoint = history.length;
    history.push({ role: "user", content: input });
    process.stdout.write(`\n${DIM}AGENT${RST}\n`);

    try {
      await runAgentTurn(systemPrompt, history);
    } catch (err) {
      process.stdout.write(
        `\x1b[31merror: ${err instanceof Error ? err.message : err}\x1b[0m\n`,
      );
      history.length = checkpoint;
    }
  });

  prompt.registerSlashCommand({
    name: "clear",
    description: "Clear session history",
    action: () => {
      history.length = 0;
      process.stdout.write(`${DIM}Session cleared.${RST}\n`);
    },
  });

  const exit = () => {
    process.stdout.write("\nBye!\n");
    process.exit(0);
  };

  prompt.registerSlashCommand({ name: "exit", description: "Exit", action: exit });
  prompt.registerSlashCommand({ name: "q", description: "Exit (shortcut)", action: exit });
}

main();
