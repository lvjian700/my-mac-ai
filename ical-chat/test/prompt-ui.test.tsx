import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Readable, Writable } from "node:stream";
import test, { afterEach, beforeEach } from "node:test";
import React from "react";
import { render } from "ink";
import { PromptApp, startPrompt } from "../src/ui.js";
import type {
  AssistantResponseUpdater,
  Prompt,
  PromptAppProps,
  SlashCommand,
} from "../src/ui.js";

const KEY = {
  ctrlQ: "\x11",
  ctrlR: "\x12",
  delete: "\x7f",
  down: "\x1B[B",
  enter: "\r",
  escape: "\x1B",
  tab: "\t",
  up: "\x1B[A",
};

const ANSI_PATTERN =
  /\u001B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\u0007]*(?:\u0007|\u001B\\))/g;

let tempDir: string | undefined;
let originalHistoryPath: string | undefined;

beforeEach(() => {
  originalHistoryPath = process.env.ICAL_CHAT_HISTORY_PATH;
  tempDir = mkdtempSync(join(tmpdir(), "ical-chat-test-"));
  process.env.ICAL_CHAT_HISTORY_PATH = join(tempDir, "history.jsonl");
});

afterEach(() => {
  if (originalHistoryPath === undefined) {
    delete process.env.ICAL_CHAT_HISTORY_PATH;
  } else {
    process.env.ICAL_CHAT_HISTORY_PATH = originalHistoryPath;
  }
  if (tempDir) rmSync(tempDir, { recursive: true, force: true });
  tempDir = undefined;
  originalHistoryPath = undefined;
});

class TestStdin extends Readable {
  isTTY = true;
  isRaw = false;

  _read() {}

  setRawMode(value: boolean) {
    this.isRaw = value;
    return this;
  }

  ref() {
    return this;
  }

  unref() {
    return this;
  }

  send(value: string) {
    this.push(value);
  }
}

class TestOutput extends Writable {
  columns = 100;
  rows = 40;
  isTTY = true;
  readonly writes: string[] = [];

  _write(
    chunk: string | Buffer,
    _encoding: BufferEncoding,
    callback: (error?: Error | null) => void,
  ) {
    this.writes.push(String(chunk));
    callback();
  }

  text() {
    return this.writes.join("").replace(ANSI_PATTERN, "");
  }
}

interface Harness {
  commands: SlashCommand[];
  input: TestStdin;
  output: TestOutput;
  unmount(): void;
}

interface StartedPromptHarness {
  input: TestStdin;
  output: TestOutput;
  prompt: Prompt;
  unmount(): void;
}

function createHarness(
  props: Pick<PromptAppProps, "onMessage"> & Partial<PromptAppProps>,
): Harness {
  const input = new TestStdin();
  const output = new TestOutput();
  const error = new TestOutput();
  const commands = props.commands ?? [];

  const instance = render(
    <PromptApp
      onMessage={props.onMessage}
      options={props.options}
      commands={commands}
    />,
    {
      stdin: input as unknown as NodeJS.ReadStream,
      stdout: output as unknown as NodeJS.WriteStream,
      stderr: error as unknown as NodeJS.WriteStream,
      exitOnCtrlC: false,
    },
  );

  return {
    commands,
    input,
    output,
    unmount: () => instance.unmount(),
  };
}

function createStartedPromptHarness(
  props: Pick<PromptAppProps, "onMessage"> & Partial<Pick<PromptAppProps, "options">>,
): StartedPromptHarness {
  const input = new TestStdin();
  const output = new TestOutput();
  const error = new TestOutput();

  const prompt = startPrompt(props.onMessage, props.options, {
    stdin: input as unknown as NodeJS.ReadStream,
    stdout: output as unknown as NodeJS.WriteStream,
    stderr: error as unknown as NodeJS.WriteStream,
    exitOnCtrlC: false,
  });

  return {
    input,
    output,
    prompt,
    unmount: () => prompt.pause(),
  };
}

function seedHistory(entries: string[]) {
  assert.ok(process.env.ICAL_CHAT_HISTORY_PATH);
  writeFileSync(
    process.env.ICAL_CHAT_HISTORY_PATH,
    entries
      .map((text) =>
        JSON.stringify({ text, createdAt: "2026-05-10T00:00:00.000Z" }),
      )
      .join("\n") + "\n",
  );
}

async function settle() {
  await new Promise<void>((resolve) => setImmediate(resolve));
  await new Promise<void>((resolve) => setImmediate(resolve));
}

async function waitFor(assertion: () => void, timeoutMs = 1000) {
  const start = Date.now();
  let lastError: unknown;

  while (Date.now() - start < timeoutMs) {
    try {
      assertion();
      return;
    } catch (err) {
      lastError = err;
      await settle();
    }
  }

  throw lastError;
}

async function send(input: TestStdin, value: string) {
  input.send(value);
  await settle();
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((nextResolve) => {
    resolve = nextResolve;
  });
  return { promise, resolve };
}

test("normal submit sends the prompt and records prompt history", async () => {
  const messages: string[] = [];
  const harness = createHarness({
    onMessage: async (input) => {
      messages.push(input);
      return "done";
    },
  });

  try {
    await send(harness.input, "what is next?");
    await waitFor(() => assert.match(harness.output.text(), /what is next\?/));
    await send(harness.input, KEY.enter);

    await waitFor(() => assert.deepEqual(messages, ["what is next?"]));
    assert.match(
      harness.output.text(),
      /what is next\?/,
      "submitted prompt should be rendered",
    );
    assert.match(
      readFileSync(process.env.ICAL_CHAT_HISTORY_PATH!, "utf-8"),
      /what is next\?/,
      "submitted prompt should be written to the env-scoped history file",
    );
  } finally {
    harness.unmount();
  }
});

test("slash command popup supports tab completion then enter", async () => {
  let memoryCommandCount = 0;
  const messages: string[] = [];
  const harness = createStartedPromptHarness({
    onMessage: async (input) => {
      messages.push(input);
    },
  });

  try {
    harness.prompt.registerSlashCommand({
      name: "clear",
      description: "Clear session",
      action: () => {},
    });
    harness.prompt.registerSlashCommand({
      name: "memory",
      description: "Edit memory",
      action: () => {
        memoryCommandCount++;
      },
    });

    await send(harness.input, "/m");
    await waitFor(() => assert.match(harness.output.text(), /Edit memory/));
    await send(harness.input, KEY.tab);
    await waitFor(() => assert.match(harness.output.text(), /\/memory/));
    await send(harness.input, KEY.enter);

    await waitFor(() => assert.equal(memoryCommandCount, 1));
    assert.deepEqual(messages, []);
  } finally {
    harness.unmount();
  }
});

test("help popup opens and escape returns to normal prompt submission", async () => {
  let commandCount = 0;
  const messages: string[] = [];
  const harness = createHarness({
    commands: [
      {
        name: "clear",
        description: "Clear session",
        action: () => {
          commandCount++;
        },
      },
    ],
    onMessage: async (input) => {
      messages.push(input);
    },
  });

  try {
    await send(harness.input, "?");
    await waitFor(() => {
      assert.match(harness.output.text(), /Clear session/);
    });

    await send(harness.input, KEY.escape);
    await send(harness.input, "hello after help");
    await send(harness.input, KEY.enter);

    await waitFor(() => assert.deepEqual(messages, ["hello after help"]));
    assert.equal(commandCount, 0);
  } finally {
    harness.unmount();
  }
});

test("history up and down restore the in-progress draft", async () => {
  seedHistory(["older prompt", "newer prompt"]);
  const messages: string[] = [];
  const harness = createHarness({
    onMessage: async (input) => {
      messages.push(input);
    },
  });

  try {
    await send(harness.input, "draft prompt");
    await waitFor(() => assert.match(harness.output.text(), /draft prompt/));
    await send(harness.input, KEY.up);
    await waitFor(() => assert.match(harness.output.text(), /newer prompt/));
    await send(harness.input, KEY.down);
    await waitFor(() => assert.match(harness.output.text(), /draft prompt/));
    await send(harness.input, KEY.enter);

    await waitFor(() => assert.deepEqual(messages, ["draft prompt"]));
  } finally {
    harness.unmount();
  }
});

test("history up can submit the newest saved prompt", async () => {
  seedHistory(["older prompt", "newer prompt"]);
  const messages: string[] = [];
  const harness = createHarness({
    onMessage: async (input) => {
      messages.push(input);
    },
  });

  try {
    await send(harness.input, KEY.up);
    await waitFor(() => assert.match(harness.output.text(), /newer prompt/));
    await send(harness.input, KEY.enter);

    await waitFor(() => assert.deepEqual(messages, ["newer prompt"]));
  } finally {
    harness.unmount();
  }
});

test("delete key removes the previous character at the end of the prompt", async () => {
  const messages: string[] = [];
  const harness = createHarness({
    onMessage: async (input) => {
      messages.push(input);
    },
  });

  try {
    await send(harness.input, "abc");
    await waitFor(() => assert.match(harness.output.text(), /abc/));
    await send(harness.input, KEY.delete);
    await waitFor(() => assert.match(harness.output.text(), /ab/));
    await send(harness.input, KEY.enter);

    await waitFor(() => assert.deepEqual(messages, ["ab"]));
  } finally {
    harness.unmount();
  }
});

test("Ctrl-R history search restores the selected prompt", async () => {
  seedHistory(["alpha older", "alpha newer"]);
  const messages: string[] = [];
  const harness = createHarness({
    onMessage: async (input) => {
      messages.push(input);
    },
  });

  try {
    await send(harness.input, KEY.ctrlR);
    await waitFor(() => assert.match(harness.output.text(), /history search/));
    await send(harness.input, "alpha");
    await waitFor(() => assert.match(harness.output.text(), /alpha newer/));
    await send(harness.input, KEY.ctrlR);
    await waitFor(() => assert.match(harness.output.text(), /alpha older/));
    await send(harness.input, KEY.enter);
    await waitFor(() => assert.match(harness.output.text(), /alpha older/));
    await send(harness.input, KEY.enter);

    await waitFor(() => assert.deepEqual(messages, ["alpha older"]));
  } finally {
    harness.unmount();
  }
});

test("Ctrl-Q invokes the registered shortcut command", async () => {
  let shortcutCount = 0;
  const messages: string[] = [];
  const harness = createStartedPromptHarness({
    onMessage: async (input) => {
      messages.push(input);
    },
  });

  try {
    harness.prompt.registerSlashCommand({
      name: "exit",
      description: "Exit",
      shortcut: { ctrl: true, name: "q" },
      action: () => {
        shortcutCount++;
      },
    });

    await send(harness.input, "?");
    await waitFor(() => assert.match(harness.output.text(), /Exit/));
    await send(harness.input, KEY.escape);
    await send(harness.input, KEY.ctrlQ);

    await waitFor(() => assert.equal(shortcutCount, 1));
    assert.deepEqual(messages, []);
  } finally {
    harness.unmount();
  }
});

test("input is disabled while onMessage is pending", async () => {
  const pending = deferred<string>();
  const messages: string[] = [];
  const harness = createHarness({
    onMessage: async (input, updateAssistantResponse: AssistantResponseUpdater) => {
      messages.push(input);
      updateAssistantResponse({
        state: "loading",
        body: "working",
        timestamp: new Date(),
      });
      return pending.promise;
    },
  });

  try {
    await send(harness.input, "first prompt");
    await send(harness.input, KEY.enter);
    await waitFor(() => assert.deepEqual(messages, ["first prompt"]));
    await waitFor(() => assert.match(harness.output.text(), /working/));

    await send(harness.input, "ignored prompt");
    await send(harness.input, KEY.enter);
    assert.deepEqual(messages, ["first prompt"]);

    pending.resolve("done");
    await waitFor(() => assert.match(harness.output.text(), /done/));
    assert.deepEqual(messages, ["first prompt"]);
  } finally {
    harness.unmount();
  }
});
