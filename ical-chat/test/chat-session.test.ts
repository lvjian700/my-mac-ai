import { describe, expect, test, mock } from "bun:test";
import type Anthropic from "@anthropic-ai/sdk";
import { ChatSession } from "../src/chat-session.js";

type ContentBlock = Anthropic.ContentBlock;
type MessageParam = Anthropic.MessageParam;

function makeTextBlock(text: string): ContentBlock {
  return { type: "text", text } as ContentBlock;
}

function makeToolUseBlock(
  id: string,
  name: string,
  input: Record<string, unknown>,
): ContentBlock {
  return { type: "tool_use", id, name, input } as ContentBlock;
}

function makeStream(blocks: ContentBlock[], stop_reason = "end_turn") {
  const textDeltas = blocks
    .filter((b) => b.type === "text")
    .map((b) => (b as { text: string }).text);

  const finalMsg = {
    id: "msg_test",
    type: "message",
    role: "assistant",
    content: blocks,
    model: "claude-sonnet-4-6",
    stop_reason,
    stop_sequence: null,
    usage: { input_tokens: 1, output_tokens: 1 },
  } as unknown as Anthropic.Message;

  const handlers: Record<string, Array<(...args: unknown[]) => void>> = {};

  return {
    on(event: string, cb: (...args: unknown[]) => void) {
      handlers[event] ??= [];
      handlers[event].push(cb);
      return this;
    },
    async finalMessage() {
      for (const t of textDeltas) {
        for (const cb of handlers["text"] ?? []) cb(t, t);
      }
      return finalMsg;
    },
  };
}

function mockClient(
  responses: Array<{ blocks: ContentBlock[]; stop_reason?: string }>,
): Anthropic {
  let call = 0;
  const stream = mock(() => {
    const resp = responses[call++] ?? { blocks: [] };
    return makeStream(resp.blocks, resp.stop_reason);
  });
  return { messages: { stream } } as unknown as Anthropic;
}

describe("ChatSession", () => {
  test("sendText resolves with streamed text", async () => {
    const client = mockClient([{ blocks: [makeTextBlock("Hello!")] }]);
    const session = ChatSession.connect({
      client,
      instructions: "You are helpful.",
    });

    const result = await session.sendText("hi");
    expect(result).toBe("Hello!");
  });

  test("onTextDelta fires for each text delta", async () => {
    const client = mockClient([{ blocks: [makeTextBlock("world")] }]);
    const deltas: string[] = [];
    const session = ChatSession.connect({
      client,
      instructions: "sys",
      onTextDelta: (d) => deltas.push(d),
    });

    await session.sendText("go");
    expect(deltas).toEqual(["world"]);
  });

  test("injectContextMessage adds to history without sending", () => {
    const client = mockClient([]);
    const session = new ChatSession({ client, instructions: "sys" });
    session.injectContextMessage("background info");
    expect((client.messages.stream as ReturnType<typeof mock>).mock.calls.length).toBe(0);
  });

  test("clearHistory resets the conversation", async () => {
    const client = mockClient([
      { blocks: [makeTextBlock("first")] },
      { blocks: [makeTextBlock("second")] },
    ]);
    const session = ChatSession.connect({
      client,
      instructions: "sys",
    });

    await session.sendText("hello");
    session.clearHistory();

    const streamMock = client.messages.stream as ReturnType<typeof mock>;
    await session.sendText("fresh start");
    const lastCall = streamMock.mock.calls.at(-1) as [{ messages: MessageParam[] }];
    expect(lastCall[0].messages).toHaveLength(1);
    expect(lastCall[0].messages[0]).toMatchObject({ role: "user", content: "fresh start" });
  });

  test("tool_use stop reason triggers executeTool and re-requests", async () => {
    const client = mockClient([
      {
        blocks: [makeToolUseBlock("tu_1", "write_memory", { content: "- no Mondays" })],
        stop_reason: "tool_use",
      },
      { blocks: [makeTextBlock("Saved.")], stop_reason: "end_turn" },
    ]);

    const statuses: string[] = [];
    const session = ChatSession.connect({
      client,
      instructions: "sys",
      onStatus: (s) => statuses.push(s),
    });

    const result = await session.sendText("remember: no Mondays");
    expect(result).toBe("Saved.");
    expect(statuses.some((s) => s.includes("write_memory"))).toBe(true);
  });
});
