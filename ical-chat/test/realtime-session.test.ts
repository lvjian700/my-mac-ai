import { describe, expect, test } from "bun:test";
import {
  buildSessionUpdateEvent,
  getRealtimeErrorMessage,
  RealtimeSession,
  type RealtimeEvent,
  type RealtimeTransport,
} from "../src/realtime/session.js";

class MockTransport implements RealtimeTransport {
  readonly sent: RealtimeEvent[] = [];
  private eventHandler: ((event: RealtimeEvent) => void) | undefined;
  private closeHandler: (() => void) | undefined;
  private errorHandler: ((err: Error) => void) | undefined;

  send(event: RealtimeEvent): void {
    this.sent.push(event);
  }

  close(): void {
    this.closeHandler?.();
  }

  onEvent(handler: (event: RealtimeEvent) => void): void {
    this.eventHandler = handler;
  }

  onClose(handler: () => void): void {
    this.closeHandler = handler;
  }

  onError(handler: (err: Error) => void): void {
    this.errorHandler = handler;
  }

  emit(event: RealtimeEvent): void {
    this.eventHandler?.(event);
  }

  emitError(err: Error): void {
    this.errorHandler?.(err);
  }
}

describe("RealtimeSession", () => {
  test("builds a gpt-realtime-2 text session with function tools", () => {
    const event = buildSessionUpdateEvent({
      instructions: "hello",
      outputMode: "text",
    });

    expect(event.type).toBe("session.update");
    expect((event.session as { model: string }).model).toBe("gpt-realtime-2");
    expect((event.session as { output_modalities: string[] }).output_modalities)
      .toEqual(["text"]);
    expect((event.session as { tools: unknown[] }).tools).toHaveLength(2);
  });

  test("builds Realtime 2 audio session shape", () => {
    const event = buildSessionUpdateEvent({
      instructions: "hello",
      outputMode: "audio",
      voice: "marin",
    });

    expect(event).toMatchObject({
      type: "session.update",
      session: {
        type: "realtime",
        model: "gpt-realtime-2",
        output_modalities: ["audio"],
        audio: {
          input: {
            format: {
              type: "audio/pcm",
              rate: 24000,
            },
            turn_detection: {
              type: "semantic_vad",
            },
          },
          output: {
            format: {
              type: "audio/pcm",
              rate: 24000,
            },
            voice: "marin",
          },
        },
      },
    });
    expect((event.session as Record<string, unknown>).input_audio_format)
      .toBeUndefined();
    expect((event.session as Record<string, unknown>).output_audio_format)
      .toBeUndefined();
  });

  test("sends user text and resolves text deltas on response.done", async () => {
    const transport = new MockTransport();
    const session = RealtimeSession.connect({
      apiKey: "test",
      instructions: "hello",
      outputMode: "text",
      transport,
    });

    const response = session.sendText("what is next?");

    expect(transport.sent.at(-2)).toMatchObject({
      type: "conversation.item.create",
    });
    expect(transport.sent.at(-1)).toMatchObject({ type: "response.create" });

    transport.emit({ type: "response.output_text.delta", delta: "done" });
    transport.emit({ type: "response.done", response: { output: [] } });

    await expect(response).resolves.toBe("done");
  });

  test("executes function calls and asks Realtime for a follow-up response", () => {
    const transport = new MockTransport();
    RealtimeSession.connect({
      apiKey: "test",
      instructions: "hello",
      outputMode: "text",
      transport,
    });

    transport.emit({
      type: "response.done",
      response: {
        output: [
          {
            type: "function_call",
            name: "unknown",
            call_id: "call_123",
            arguments: "{}",
          },
        ],
      },
    });

    expect(transport.sent.at(-2)).toMatchObject({
      type: "conversation.item.create",
      item: {
        type: "function_call_output",
        call_id: "call_123",
        output: "Unknown tool: unknown",
      },
    });
    expect(transport.sent.at(-1)).toMatchObject({
      type: "response.create",
    });
  });

  test("does not count raw audio append frames as idle activity", () => {
    const transport = new MockTransport();
    let activityCount = 0;
    const session = RealtimeSession.connect({
      apiKey: "test",
      instructions: "hello",
      outputMode: "audio",
      transport,
      onActivity: () => {
        activityCount += 1;
      },
    });

    session.appendInputAudio("AAAA");
    session.appendInputAudio("BBBB");

    expect(activityCount).toBe(0);

    transport.emit({ type: "input_audio_buffer.speech_started" });

    expect(activityCount).toBe(1);
  });

  test("extracts nested Realtime error messages", () => {
    expect(
      getRealtimeErrorMessage({
        type: "error",
        error: { message: "bad session" },
      }),
    ).toBe("bad session");
  });
});
