export type CliMode = "text" | "voice";

export interface CliOptions {
  mode: CliMode;
  debug: boolean;
}

export function parseCliOptions(args: readonly string[]): CliOptions {
  let mode: CliMode = "text";
  let debug = false;

  for (const arg of args) {
    if (arg === "--voice") {
      mode = "voice";
      continue;
    }

    if (arg === "--debug" || arg === "--debug-realtime") {
      debug = true;
      continue;
    }

    if (arg.startsWith("-")) {
      throw new Error(`Unknown flag: ${arg}`);
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return { mode, debug };
}
