import { parseCliOptions } from "./cli.js";
import { setDebugLoggingEnabled } from "./debug.js";
import { runTextChat } from "./text-chat.js";
import { runVoiceChat } from "./voice/voice-chat.js";

async function main() {
  const options = parseCliOptions(process.argv.slice(2));
  setDebugLoggingEnabled(options.debug);

  if (options.mode === "voice") {
    await runVoiceChat();
    return;
  }

  await runTextChat();
}

main().catch((err) => {
  console.error(`\x1b[31merror: ${err instanceof Error ? err.message : err}\x1b[0m`);
  process.exit(1);
});
