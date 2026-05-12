import { execFileSync } from "child_process";
import { writeFileSync, mkdirSync } from "fs";
import { dirname } from "path";
import { homedir } from "os";

const MEMORY_PATH = `${homedir()}/.my-mac-ai/ical/memory.yaml`;

export interface JsonObjectSchema {
  type: "object";
  properties: Record<string, unknown>;
  required?: string[];
  additionalProperties?: boolean;
}

export interface CaliTool {
  type: "function";
  name: string;
  description: string;
  parameters: JsonObjectSchema;
}

export const tools: CaliTool[] = [
  {
    type: "function",
    name: "ical",
    description:
      "Run the ical CLI to read or write Apple Calendar events. Always use --format json for structured output.",
    parameters: {
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
      additionalProperties: false,
    },
  },
  {
    type: "function",
    name: "write_memory",
    description:
      "Write the calendar rules memory file. Call this when the user describes a calendar habit to save.",
    parameters: {
      type: "object",
      properties: {
        content: {
          type: "string",
          description: "Full YAML content for the memory file",
        },
      },
      required: ["content"],
      additionalProperties: false,
    },
  },
];

export type ToolInput = {
  args?: string[];
  content?: string;
};

export function executeTool(name: string, input: ToolInput): string {
  if (name === "ical") {
    try {
      const args = input.args ?? [];
      return execFileSync("ical", args, {
        encoding: "utf-8",
        timeout: 10_000,
      });
    } catch (err) {
      const e = err as { stderr?: string; stdout?: string; message?: string };
      return e.stderr || e.stdout || e.message || String(err);
    }
  }

  if (name === "write_memory") {
    try {
      mkdirSync(dirname(MEMORY_PATH), { recursive: true });
      writeFileSync(MEMORY_PATH, input.content ?? "", "utf-8");
      return `Saved to ${MEMORY_PATH}`;
    } catch (err) {
      return `Error: ${err instanceof Error ? err.message : err}`;
    }
  }

  return `Unknown tool: ${name}`;
}
