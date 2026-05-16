import Anthropic from "@anthropic-ai/sdk";
import { execFileSync } from "child_process";

const ICAL_TOOL: Anthropic.Tool = {
  name: "ical",
  description:
    "Run the ical CLI to read or write Apple Calendar events. Always use --format json for structured output.",
  input_schema: {
    type: "object",
    properties: {
      args: {
        type: "array",
        items: { type: "string" },
        description:
          "Arguments for the ical command, e.g. ['events', '--from', 'today', '--to', 'tomorrow', '--format', 'json']",
      },
    },
    required: ["args"],
  },
};

export function requireAnthropicKey(env: NodeJS.ProcessEnv = process.env): string {
  const apiKey = env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY is required");
  return apiKey;
}

function executeIcal(args: string[]): string {
  try {
    return execFileSync("ical", args, { encoding: "utf-8", timeout: 10_000 });
  } catch (err) {
    const e = err as { stderr?: string; stdout?: string; message?: string };
    return e.stderr || e.stdout || e.message || String(err);
  }
}

function getTimezone(): string {
  try {
    return execFileSync("date", ["+%Z"], { encoding: "utf-8" }).trim();
  } catch {
    return "UTC";
  }
}

export async function runICalAgent(request: string): Promise<string> {
  const client = new Anthropic({ apiKey: requireAnthropicKey() });
  const today = new Date().toLocaleDateString("en-CA");
  const tz = getTimezone();

  const systemPrompt = `You are a calendar operations agent. Today is ${today}, timezone ${tz}. Execute the requested calendar operation using the ical tool and return a concise factual summary. Do not narrate — just do and report.`;

  const messages: Anthropic.MessageParam[] = [{ role: "user", content: request }];

  while (true) {
    const response = await client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      system: systemPrompt,
      tools: [ICAL_TOOL],
      messages,
    });

    messages.push({ role: "assistant", content: response.content });

    if (response.stop_reason === "end_turn") {
      return response.content
        .filter((b): b is Anthropic.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("");
    }

    const toolUses = response.content.filter(
      (b): b is Anthropic.ToolUseBlock => b.type === "tool_use",
    );

    if (toolUses.length === 0) break;

    const toolResults: Anthropic.ToolResultBlockParam[] = toolUses.map((use) => {
      const input = use.input as { args?: string[] };
      return {
        type: "tool_result",
        tool_use_id: use.id,
        content: executeIcal(input.args ?? []),
      };
    });

    messages.push({ role: "user", content: toolResults });
  }

  return "(no response)";
}
