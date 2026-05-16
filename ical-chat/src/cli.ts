export type CliMode = "text";

export interface CliOptions {
  mode: CliMode;
  debug: boolean;
}

export function parseCliOptions(args: readonly string[]): CliOptions {
  let debug = false;

  for (const arg of args) {
    if (arg === "--debug") {
      debug = true;
      continue;
    }

    if (arg.startsWith("-")) {
      throw new Error(`Unknown flag: ${arg}`);
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return { mode: "text", debug };
}
