import { describe, expect, test } from "bun:test";
import {
  buildSessionUpdateEvent,
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
});
