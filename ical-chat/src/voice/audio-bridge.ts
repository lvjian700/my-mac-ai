import { spawn, type ChildProcessWithoutNullStreams } from "child_process";
import { existsSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import { debugLogger } from "../debug.js";

export type AudioBridgeEvent =
  | {
      type: "input_audio";
      audio: string;
      sample_rate?: number;
      channels?: number;
      format?: string;
    }
  | { type: "activity"; activity?: string }
  | { type: "error"; message: string }
  | { type: "shutdown" };

export interface AudioBridge {
  sendOutputAudio(audio: string, sampleRate?: number): void;
  shutdown(): void;
  onEvent(handler: (event: AudioBridgeEvent) => void): void;
  onError(handler: (err: Error) => void): void;
  onClose(handler: () => void): void;
}

const FRAME_HEADER_BYTES = 4;

export function encodeFrame(payload: unknown): Buffer {
  const body = Buffer.from(JSON.stringify(payload), "utf-8");
  const header = Buffer.alloc(FRAME_HEADER_BYTES);
  header.writeUInt32BE(body.length, 0);
  return Buffer.concat([header, body]);
}

export function decodeFrames(
  chunk: Buffer,
  state: { buffer: Buffer },
): unknown[] {
  state.buffer = Buffer.concat([state.buffer, chunk]);
  const frames: unknown[] = [];

  while (state.buffer.length >= FRAME_HEADER_BYTES) {
    const length = state.buffer.readUInt32BE(0);
    if (state.buffer.length < FRAME_HEADER_BYTES + length) break;

    const body = state.buffer.subarray(
      FRAME_HEADER_BYTES,
      FRAME_HEADER_BYTES + length,
    );
    frames.push(JSON.parse(body.toString("utf-8")) as unknown);
    state.buffer = state.buffer.subarray(FRAME_HEADER_BYTES + length);
  }

  return frames;
}

export class NativeAudioBridge implements AudioBridge {
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly eventHandlers: Array<(event: AudioBridgeEvent) => void> = [];
  private readonly errorHandlers: Array<(err: Error) => void> = [];
  private readonly closeHandlers: Array<() => void> = [];
  private readonly decoderState = { buffer: Buffer.alloc(0) };

  constructor(executablePath = resolveAudioHelperPath()) {
    debugLogger.log("audio", "spawn helper", { executablePath });
    this.child = spawn(executablePath, [], {
      stdio: ["pipe", "pipe", "pipe"],
    });

    this.child.stdout.on("data", (chunk: Buffer) => {
      try {
        for (const frame of decodeFrames(chunk, this.decoderState)) {
          if (isAudioBridgeEvent(frame)) {
            this.eventHandlers.forEach((handler) => handler(frame));
          }
        }
      } catch (err) {
        this.emitError(err);
      }
    });

    this.child.stderr.on("data", (chunk: Buffer) => {
      this.emitError(new Error(chunk.toString("utf-8").trim()));
    });

    this.child.on("error", (err) => this.emitError(err));
    this.child.on("close", () => {
      this.closeHandlers.forEach((handler) => handler());
    });
  }

  sendOutputAudio(audio: string, sampleRate = 24_000): void {
    debugLogger.log("audio", "send output audio", {
      audioBytesBase64: audio.length,
      sampleRate,
    });
    this.child.stdin.write(
      encodeFrame({
        type: "output_audio",
        audio: convertPcm16Base64ToF32Base64(audio),
        sample_rate: sampleRate,
        channels: 1,
        format: "f32le",
      }),
    );
  }

  shutdown(): void {
    if (!this.child.killed) {
      debugLogger.log("audio", "shutdown helper");
      this.child.stdin.write(encodeFrame({ type: "shutdown" }));
      this.child.kill("SIGTERM");
    }
  }

  onEvent(handler: (event: AudioBridgeEvent) => void): void {
    this.eventHandlers.push(handler);
  }

  onError(handler: (err: Error) => void): void {
    this.errorHandlers.push(handler);
  }

  onClose(handler: () => void): void {
    this.closeHandlers.push(handler);
  }

  private emitError(err: unknown): void {
    const error = err instanceof Error ? err : new Error(String(err));
    this.errorHandlers.forEach((handler) => handler(error));
  }
}

export interface ResolveAudioHelperPathOptions {
  env?: NodeJS.ProcessEnv;
  argv?: readonly string[];
  execPath?: string;
  moduleUrl?: string;
  exists?: (path: string) => boolean;
}

export function resolveAudioHelperPath({
  env = process.env,
  argv = process.argv,
  execPath = process.execPath,
  moduleUrl = import.meta.url,
  exists = existsSync,
}: ResolveAudioHelperPathOptions = {}): string {
  if (env.CALI_VOICE_AUDIO_HELPER) {
    return env.CALI_VOICE_AUDIO_HELPER;
  }

  const srcDir = dirname(fileURLToPath(moduleUrl));
  const packageRoot = join(srcDir, "../../native/voice-audio");
  const launchedScriptPath = argv[1];
  const installedFromScriptPath = launchedScriptPath
    ? join(dirname(launchedScriptPath), "../libexec/cali/cali-voice-audio")
    : undefined;
  const installedPath = join(
    dirname(execPath),
    "../libexec/cali/cali-voice-audio",
  );
  const releasePath = join(
    packageRoot,
    ".build/release/cali-voice-audio",
  );
  const debugPath = join(packageRoot, ".build/debug/cali-voice-audio");

  if (installedFromScriptPath && exists(installedFromScriptPath)) {
    return installedFromScriptPath;
  }
  if (exists(installedPath)) return installedPath;
  if (exists(releasePath)) return releasePath;
  if (exists(debugPath)) return debugPath;

  return installedFromScriptPath ?? releasePath;
}

export function convertF32Base64ToPcm16Base64(audio: string): string {
  const f32 = Buffer.from(audio, "base64");
  const samples = Math.floor(f32.length / 4);
  const pcm16 = Buffer.alloc(samples * 2);

  for (let i = 0; i < samples; i++) {
    const sample = Math.max(-1, Math.min(1, f32.readFloatLE(i * 4)));
    const intSample = sample < 0 ? sample * 0x8000 : sample * 0x7fff;
    pcm16.writeInt16LE(Math.round(intSample), i * 2);
  }

  return pcm16.toString("base64");
}

export function convertPcm16Base64ToF32Base64(audio: string): string {
  const pcm16 = Buffer.from(audio, "base64");
  const samples = Math.floor(pcm16.length / 2);
  const f32 = Buffer.alloc(samples * 4);

  for (let i = 0; i < samples; i++) {
    const sample = pcm16.readInt16LE(i * 2);
    f32.writeFloatLE(sample < 0 ? sample / 0x8000 : sample / 0x7fff, i * 4);
  }

  return f32.toString("base64");
}

function isAudioBridgeEvent(value: unknown): value is AudioBridgeEvent {
  if (!value || typeof value !== "object") return false;
  const event = value as {
    type?: unknown;
    audio?: unknown;
    activity?: unknown;
    message?: unknown;
  };

  if (event.type === "input_audio") return typeof event.audio === "string";
  if (event.type === "activity") {
    return (
      event.activity === undefined || typeof event.activity === "string"
    );
  }
  if (event.type === "shutdown") return true;
  if (event.type === "error") return typeof event.message === "string";
  return false;
}
