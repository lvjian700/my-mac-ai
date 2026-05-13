import { buildSystemPrompt } from "../session.js";
import {
  RealtimeSession,
  realtimeConfigFromEnv,
  requireOpenAIKey,
} from "../realtime/session.js";
import { CALI } from "../personalities/cali.js";
import {
  convertF32Base64ToPcm16Base64,
  NativeAudioBridge,
  type AudioBridge,
} from "./audio-bridge.js";
import { startVoiceIdleTimeout } from "./idle-timeout.js";
import { debugLogger } from "../debug.js";

const DEFAULT_USER_NAME = "You";

export interface VoiceChatOptions {
  audioBridge?: AudioBridge;
}

export async function runVoiceChat(options: VoiceChatOptions = {}) {
  const userName = process.env.CALI_USER_NAME ?? DEFAULT_USER_NAME;
  const systemPrompt = buildVoiceSystemPrompt(
    buildSystemPrompt(userName, CALI),
  );
  const realtimeConfig = realtimeConfigFromEnv();
  const audioBridge = options.audioBridge ?? new NativeAudioBridge();
  const debug = debugLogger;

  let shuttingDown = false;
  let session: RealtimeSession | undefined;

  const shutdown = (message = "voice mode idle for 60s. shutting down.") => {
    if (shuttingDown) return;
    shuttingDown = true;
    debug.log("voice", "shutdown", { message });
    idleTimeout.stop();
    session?.close();
    audioBridge.shutdown();
    console.log(`\n${message}`);
    process.exit(0);
  };

  const idleTimeout = startVoiceIdleTimeout({
    shutdown: () => shutdown(),
  });

  session = RealtimeSession.connect({
    apiKey: requireOpenAIKey(),
    instructions: systemPrompt,
    outputMode: "audio",
    ...realtimeConfig,
    debug,
    onActivity: () => idleTimeout.reset(),
    onAudioDelta: (delta) => {
      idleTimeout.reset();
      audioBridge.sendOutputAudio(delta);
    },
    onStatus: (message) => {
      idleTimeout.reset();
      debug.log("voice", "status", { message });
      console.log(message);
    },
    onError: (err) => {
      console.error(`realtime error: ${err.message}`);
    },
  });

  audioBridge.onEvent((event) => {
    debug.log("voice", "audio bridge event", {
      type: event.type,
      audioBytesBase64:
        event.type === "input_audio" ? event.audio.length : undefined,
      sampleRate:
        event.type === "input_audio" ? event.sample_rate : undefined,
      channels:
        event.type === "input_audio" ? event.channels : undefined,
      format: event.type === "input_audio" ? event.format : undefined,
    });

    if (event.type === "input_audio") {
      session?.appendInputAudio(
        event.format === "f32le"
          ? convertF32Base64ToPcm16Base64(event.audio)
          : event.audio,
      );
      return;
    }

    idleTimeout.reset();

    if (event.type === "error") {
      console.error(`audio error: ${event.message}`);
      return;
    }

    if (event.type === "shutdown") {
      shutdown("voice audio stopped. shutting down.");
    }
  });

  audioBridge.onError((err) => {
    idleTimeout.reset();
    debug.log("voice", "audio bridge error", { message: err.message });
    console.error(`audio error: ${err.message}`);
  });

  audioBridge.onClose(() => {
    debug.log("voice", "audio bridge close");
    shutdown("voice audio stopped. shutting down.");
  });

  process.stdin.resume();
  process.stdin.setEncoding("utf-8");
  process.stdin.on("data", () => {
    debug.log("voice", "stdin activity");
    idleTimeout.reset();
  });

  process.once("SIGINT", () => shutdown("voice mode stopped."));
  process.once("SIGTERM", () => shutdown("voice mode stopped."));

  console.log("Cali voice mode is listening. Idle shutdown: 60s.");

  await new Promise<void>(() => {});
}

function buildVoiceSystemPrompt(basePrompt: string): string {
  return [
    basePrompt,
    "## Voice Mode",
    [
      "You are speaking out loud in a terminal voice session.",
      "Keep answers short and natural.",
      "Avoid visual-only formatting such as backticks, markdown bullets, checkmarks, and block quotes.",
      "Confirm calendar writes briefly after tools succeed.",
    ].join("\n"),
  ].join("\n\n");
}
