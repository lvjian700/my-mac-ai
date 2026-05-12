export type CliMode = "text" | "voice";

export interface CliOptions {
  mode: CliMode;
}

export function parseCliOptions(args: readonly string[]): CliOptions {
  let mode: CliMode = "text";

  for (const arg of args) {
    if (arg === "--voice") {
      mode = "voice";
      continue;
    }

    if (arg.startsWith("-")) {
      throw new Error(`Unknown flag: ${arg}`);
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return { mode };
}
