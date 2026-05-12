import { executeTool, tools, type ToolInput } from "../tools.js";

export interface RealtimeFunctionCall extends Record<string, unknown> {
  type: "function_call";
  name: string;
  call_id: string;
  arguments: string;
}

export function realtimeTools() {
  return tools;
}

export function executeRealtimeFunctionCall(call: RealtimeFunctionCall): string {
  let input: ToolInput;

  try {
    input = JSON.parse(call.arguments || "{}") as ToolInput;
  } catch (err) {
    return `Error: invalid JSON arguments for ${call.name}: ${
      err instanceof Error ? err.message : err
    }`;
  }

  return executeTool(call.name, input);
}
