import { writeFileSync, mkdirSync } from "fs";
import { dirname } from "path";
import { homedir } from "os";
import type Anthropic from "@anthropic-ai/sdk";
import { runICalAgent } from "./ical-agent.js";

const MEMORY_PATH = `${homedir()}/.my-mac-ai/ical/memory.yaml`;

export type ToolInput = Record<string, unknown> & {
  request?: string;
  content?: string;
};

const TOOLS: Anthropic.Tool[] = [
  {
    name: "calendar",
    description:
      "Delegate a calendar operation to the calendar agent. Use for: queries outside " +
      "the pre-loaded snapshot range, creating, updating, or deleting events. " +
      "Do NOT use for questions answerable from the Calendar Snapshot.",
    input_schema: {
      type: "object",
      properties: {
        request: {
          type: "string",
          description:
            "Natural language description of the calendar operation to perform",
        },
      },
      required: ["request"],
    },
  },
  {
    name: "write_memory",
    description:
      "Write the calendar rules memory file. Call this when the user describes a calendar habit to save.",
    input_schema: {
      type: "object",
      properties: {
        content: {
          type: "string",
          description: "Full YAML content for the memory file",
        },
      },
      required: ["content"],
    },
  },
];

export function anthropicTools(): Anthropic.Tool[] {
  return TOOLS;
}

export async function executeTool(name: string, input: ToolInput): Promise<string> {
  if (name === "calendar") {
    return runICalAgent(input.request ?? "");
  }

  if (name === "write_memory") {
    try {
      mkdirSync(dirname(MEMORY_PATH), { recursive: true });
      writeFileSync(MEMORY_PATH, (input.content as string) ?? "", "utf-8");
      return `Saved to ${MEMORY_PATH}`;
    } catch (err) {
      return `Error: ${err instanceof Error ? err.message : err}`;
    }
  }

  return `Unknown tool: ${name}`;
}
