import {
  executeRealtimeFunctionCall,
  realtimeTools,
  type RealtimeFunctionCall,
} from "./tool-adapter.js";
import { debugLogger, type DebugLogger } from "../debug.js";

export type RealtimeOutputMode = "text" | "audio";
export type RealtimeEvent = Record<string, unknown> & { type: string };

export interface RealtimeTransport {
  send(event: RealtimeEvent): void;
  close(): void;
  onEvent(handler: (event: RealtimeEvent) => void): void;
  onClose(handler: () => void): void;
  onError(handler: (err: Error) => void): void;
}

export interface RealtimeSessionOptions {
  apiKey: string;
  instructions: string;
  model?: string;
  voice?: string;
  reasoningEffort?: string;
  outputMode: RealtimeOutputMode;
  onActivity?: () => void;
  onTextDelta?: (delta: string) => void;
  onAudioDelta?: (delta: string) => void;
  onError?: (err: Error) => void;
  onStatus?: (message: string) => void;
  debug?: DebugLogger;
  transport?: RealtimeTransport;
}

interface PendingTextResponse {
  text: string;
  resolve: (value: string) => void;
  reject: (err: Error) => void;
}

interface RealtimeResponseDone {
  response?: {
    output?: Array<Record<string, unknown>>;
  };
}

const DEFAULT_MODEL = "gpt-realtime-2";
const DEFAULT_VOICE = "marin";
const DEFAULT_REASONING_EFFORT = "medium";

export function realtimeConfigFromEnv(env: NodeJS.ProcessEnv = process.env) {
  return {
    model: env.CALI_REALTIME_MODEL ?? DEFAULT_MODEL,
    voice: env.CALI_VOICE ?? DEFAULT_VOICE,
    reasoningEffort:
      env.CALI_REALTIME_REASONING_EFFORT ?? DEFAULT_REASONING_EFFORT,
  };
}

export function requireOpenAIKey(env: NodeJS.ProcessEnv = process.env): string {
  const apiKey = env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is required");
  }
  return apiKey;
}

export function buildSessionUpdateEvent(
  options: Pick<
    RealtimeSessionOptions,
    "instructions" | "model" | "voice" | "reasoningEffort" | "outputMode"
  >,
): RealtimeEvent {
  const outputModalities =
    options.outputMode === "audio" ? ["audio"] : ["text"];

  return {
    type: "session.update",
    session: {
      type: "realtime",
      model: options.model ?? DEFAULT_MODEL,
      instructions: options.instructions,
      output_modalities: outputModalities,
      tools: realtimeTools(),
      tool_choice: "auto",
      reasoning: {
        effort: options.reasoningEffort ?? DEFAULT_REASONING_EFFORT,
      },
      ...(options.outputMode === "audio"
        ? {
            audio: {
              input: {
                format: {
                  type: "audio/pcm",
                  rate: 24_000,
                },
                turn_detection: {
                  type: "semantic_vad",
                },
              },
              output: {
                format: {
                  type: "audio/pcm",
                  rate: 24_000,
                },
                voice: options.voice ?? DEFAULT_VOICE,
              },
            },
          }
        : {}),
    },
  };
}

export class WebSocketRealtimeTransport implements RealtimeTransport {
  private ws: WebSocket;
  private isOpen = false;
  private pendingEvents: RealtimeEvent[] = [];
  private eventHandlers: Array<(event: RealtimeEvent) => void> = [];
  private closeHandlers: Array<() => void> = [];
  private errorHandlers: Array<(err: Error) => void> = [];

  constructor(apiKey: string, model: string) {
    const url = `wss://api.openai.com/v1/realtime?model=${encodeURIComponent(
      model,
    )}`;
    const HeaderWebSocket = WebSocket as unknown as {
      new (
        url: string,
        options: { headers: Record<string, string> },
      ): WebSocket;
    };
    this.ws = new HeaderWebSocket(url, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });

    this.ws.addEventListener("open", () => {
      this.isOpen = true;
      debugLogger.log("realtime", "websocket open", {
        queuedEvents: this.pendingEvents.length,
      });
      for (const event of this.pendingEvents.splice(0)) {
        this.ws.send(JSON.stringify(event));
      }
    });

    this.ws.addEventListener("message", (event) => {
      try {
        const data = typeof event.data === "string" ? event.data : "";
        if (!data) return;
        this.eventHandlers.forEach((handler) =>
          handler(JSON.parse(data) as RealtimeEvent),
        );
      } catch (err) {
        this.errorHandlers.forEach((handler) =>
          handler(err instanceof Error ? err : new Error(String(err))),
        );
      }
    });

    this.ws.addEventListener("close", () => {
      debugLogger.log("realtime", "websocket close");
      this.closeHandlers.forEach((handler) => handler());
    });

    this.ws.addEventListener("error", () => {
      debugLogger.log("realtime", "websocket error");
      this.errorHandlers.forEach((handler) =>
        handler(new Error("Realtime WebSocket error")),
      );
    });
  }

  send(event: RealtimeEvent): void {
    if (!this.isOpen) {
      this.pendingEvents.push(event);
      return;
    }

    this.ws.send(JSON.stringify(event));
  }

  close(): void {
    this.ws.close();
  }

  onEvent(handler: (event: RealtimeEvent) => void): void {
    this.eventHandlers.push(handler);
  }

  onClose(handler: () => void): void {
    this.closeHandlers.push(handler);
  }

  onError(handler: (err: Error) => void): void {
    this.errorHandlers.push(handler);
  }
}

export class RealtimeSession {
  private pendingText: PendingTextResponse | undefined;
  private closed = false;
  private readonly debug: DebugLogger;

  constructor(
    private readonly transport: RealtimeTransport,
    private readonly options: RealtimeSessionOptions,
  ) {
    this.debug = options.debug ?? debugLogger;
    this.transport.onEvent((event) => this.handleEvent(event));
    this.transport.onError((err) => this.rejectPending(err));
    this.transport.onClose(() => {
      this.closed = true;
      this.rejectPending(new Error("Realtime session closed"));
    });
  }

  static connect(options: RealtimeSessionOptions): RealtimeSession {
    const model = options.model ?? DEFAULT_MODEL;
    const transport =
      options.transport ??
      new WebSocketRealtimeTransport(options.apiKey, model);
    const session = new RealtimeSession(transport, { ...options, model });
    session.configure();
    return session;
  }

  configure(): void {
    this.send(
      buildSessionUpdateEvent({
        instructions: this.options.instructions,
        model: this.options.model,
        voice: this.options.voice,
        reasoningEffort: this.options.reasoningEffort,
        outputMode: this.options.outputMode,
      }),
    );
  }

  sendText(input: string): Promise<string> {
    if (this.pendingText) {
      return Promise.reject(new Error("Realtime response already in progress"));
    }

    this.activity();
    this.send({
      type: "conversation.item.create",
      item: {
        type: "message",
        role: "user",
        content: [{ type: "input_text", text: input }],
      },
    });

    this.send({
      type: "response.create",
      response: { output_modalities: ["text"] },
    });

    return new Promise((resolve, reject) => {
      this.pendingText = { text: "", resolve, reject };
    });
  }

  appendInputAudio(audio: string): void {
    this.debug.log("realtime", "append input audio", {
      bytesBase64: audio.length,
    });
    this.send({
      type: "input_audio_buffer.append",
      audio,
    });
  }

  close(): void {
    if (this.closed) return;
    this.closed = true;
    this.transport.close();
  }

  private handleEvent(event: RealtimeEvent): void {
    this.debug.log("realtime", "recv", summarizeEvent(event));

    if (event.type === "response.output_text.delta") {
      this.activity();
      const delta = typeof event.delta === "string" ? event.delta : "";
      this.pendingText && (this.pendingText.text += delta);
      this.options.onTextDelta?.(delta);
      return;
    }

    if (
      event.type === "response.audio.delta" ||
      event.type === "response.output_audio.delta"
    ) {
      this.activity();
      const delta = typeof event.delta === "string" ? event.delta : "";
      this.options.onAudioDelta?.(delta);
      return;
    }

    if (event.type === "input_audio_buffer.speech_started") {
      this.activity();
      this.options.onStatus?.("listening...");
      return;
    }

    if (event.type === "response.done") {
      this.activity();
      void this.handleResponseDone(
        event as RealtimeEvent & RealtimeResponseDone,
      );
      return;
    }

    if (event.type === "error") {
      const error = new Error(getRealtimeErrorMessage(event));
      this.options.onError?.(error);
      this.rejectPending(error);
    }
  }

  private async handleResponseDone(
    event: RealtimeEvent & RealtimeResponseDone,
  ): Promise<void> {
    const calls = (event.response?.output ?? []).filter(
      (item): item is RealtimeFunctionCall =>
        item.type === "function_call" &&
        typeof item.name === "string" &&
        typeof item.call_id === "string" &&
        typeof item.arguments === "string",
    );

    if (calls.length > 0) {
      for (const call of calls) {
        this.debug.log("realtime", "tool call", {
          name: call.name,
          callId: call.call_id,
          argumentBytes: call.arguments.length,
        });
        this.options.onStatus?.(`running ${call.name}...`);
        const output = executeRealtimeFunctionCall(call);
        this.activity();
        this.debug.log("realtime", "tool result", {
          name: call.name,
          callId: call.call_id,
          outputBytes: output.length,
        });
        this.send({
          type: "conversation.item.create",
          item: {
            type: "function_call_output",
            call_id: call.call_id,
            output,
          },
        });
      }

      this.send({
        type: "response.create",
        response: {
          output_modalities:
            this.options.outputMode === "audio" ? ["audio"] : ["text"],
        },
      });
      return;
    }

    const pending = this.pendingText;
    if (!pending) return;
    this.pendingText = undefined;
    pending.resolve(pending.text);
  }

  private send(event: RealtimeEvent): void {
    this.debug.log("realtime", "send", summarizeEvent(event));
    this.transport.send(event);
  }

  private activity(): void {
    this.options.onActivity?.();
  }

  private rejectPending(err: Error): void {
    const pending = this.pendingText;
    if (!pending) return;
    this.pendingText = undefined;
    pending.reject(err);
  }
}

function summarizeEvent(event: RealtimeEvent): Record<string, unknown> {
  const response = event.response as
    | {
        id?: unknown;
        status?: unknown;
        output?: unknown;
      }
    | undefined;
  const item = event.item as
    | {
        type?: unknown;
        call_id?: unknown;
        name?: unknown;
      }
    | undefined;

  return {
    type: event.type,
    responseId:
      typeof event.response_id === "string"
        ? event.response_id
        : typeof response?.id === "string"
          ? response.id
          : undefined,
    responseStatus: response?.status,
    itemType: item?.type,
    callId:
      typeof event.call_id === "string"
        ? event.call_id
        : typeof item?.call_id === "string"
          ? item.call_id
          : undefined,
    name:
      typeof event.name === "string"
        ? event.name
        : typeof item?.name === "string"
          ? item.name
          : undefined,
    deltaBytes:
      typeof event.delta === "string" ? event.delta.length : undefined,
    audioBytesBase64:
      typeof event.audio === "string" ? event.audio.length : undefined,
    outputCount: Array.isArray(response?.output)
      ? response.output.length
      : undefined,
  };
}

export function getRealtimeErrorMessage(event: RealtimeEvent): string {
  if (typeof event.message === "string") {
    return event.message;
  }

  const nested = event.error;
  if (nested && typeof nested === "object") {
    const message = (nested as { message?: unknown }).message;
    if (typeof message === "string") {
      return message;
    }
  }

  return "Realtime API error";
}
