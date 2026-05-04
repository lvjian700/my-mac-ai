import Anthropic from "@anthropic-ai/sdk";
import * as readline from "readline";
import { buildSystemPrompt } from "./session.js";
import { tools, executeTool } from "./tools.js";

const client = new Anthropic();
const MODEL = "claude-sonnet-4-6";

async function runAgentTurn(
  systemPrompt: string,
  history: Anthropic.MessageParam[]
): Promise<void> {
  while (true) {
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

    stream.on("text", (t) => process.stdout.write(t));

    const response = await stream.finalMessage();
    history.push({ role: "assistant", content: response.content });

    const toolCalls = response.content.filter(
      (b): b is Anthropic.ToolUseBlock => b.type === "tool_use"
    );

    if (toolCalls.length === 0) {
      process.stdout.write("\n");
      break;
    }

    const results: Anthropic.ToolResultBlockParam[] = toolCalls.map((call) => {
      const input = call.input as Parameters<typeof executeTool>[1];
      const args = Array.isArray(input.args) ? input.args : [];
      const label = call.name === "ical" ? `ical ${args.join(" ")}` : call.name;
      process.stdout.write(`\x1b[2m  ${label}\x1b[0m\n`);
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

  process.stdout.write("ical chat  —  Ctrl-D to exit\n\n");

  const loop = () => {
    rl.question("\x1b[1;36m> \x1b[0m", async (line) => {
      const input = line.trim();
      if (!input) {
        loop();
        return;
      }

      const checkpoint = history.length;
      history.push({ role: "user", content: input });

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
