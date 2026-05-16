import React, { useState, useRef, useEffect } from "react";
import { Box, Text, render, useApp } from "ink";
import type { RenderOptions } from "ink";
import {
  renderAssistantResponse,
  renderConversationMessage,
} from "./renderer.js";
import type { AssistantResponseMessage } from "./renderer.js";
import { CALI } from "./personalities/cali.js";
import type { AssistantPersonality } from "./personalities/types.js";
import { PromptComposer } from "./prompt-composer.js";
import type {
  KeyShortcut,
  PromptComposerSubmission,
} from "./prompt-composer.js";
export type { KeyShortcut } from "./prompt-composer.js";

export interface SlashCommand {
  name: string;
  description: string;
  shortcut?: KeyShortcut;
  action: () => void | Promise<void>;
}

export interface Prompt {
  registerSlashCommand(cmd: SlashCommand): void;
  pause(): void;
  resume(): void;
}

export type AssistantResponseUpdater = (
  response: AssistantResponseMessage,
) => void;

export interface PromptAppProps {
  onMessage: (
    input: string,
    updateAssistantResponse: AssistantResponseUpdater,
  ) => Promise<string | void>;
  options?: {
    trigger?: string;
    userName?: string;
    personality?: AssistantPersonality;
    greeting?: string;
  };
  commands: SlashCommand[];
}

interface CaliResponseProps {
  response: AssistantResponseMessage;
  personality: AssistantPersonality;
}

function CaliResponse({ response, personality }: CaliResponseProps) {
  return (
    <Box marginTop={1} marginBottom={1}>
      <Text>{renderAssistantResponse(response, personality)}</Text>
    </Box>
  );
}

export function PromptApp({ onMessage, options, commands }: PromptAppProps) {
  const trigger = options?.trigger ?? "/";
  const personality = options?.personality ?? CALI;
  const userName = options?.userName ?? "You";
  const { exit } = useApp();

  const [isProcessing, setIsProcessing] = useState(false);
  const [composerSuspended, setComposerSuspended] = useState(false);
  const [assistantResponse, setAssistantResponseState] =
    useState<AssistantResponseMessage | null>(null);
  const processingRef = useRef(false);
  const assistantResponseRef = useRef<AssistantResponseMessage | null>(null);

  const commandsRef = useRef(commands);
  useEffect(() => {
    commandsRef.current = commands;
  }, [commands]);

  // Fire greeting on mount
  useEffect(() => {
    const greeting = options?.greeting;
    if (!greeting) return;
    setProcessing(true);
    setAssistantResponse({ state: "loading", timestamp: new Date() });
    onMessage(greeting, setAssistantResponse)
      .then((body) => {
        if (typeof body === "string") {
          setAssistantResponse({ state: "presenting", body, timestamp: new Date() });
        }
      })
      .finally(() => setProcessing(false));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const setProcessing = (value: boolean) => {
    processingRef.current = value;
    setIsProcessing(value);
  };

  const setAssistantResponse = (value: AssistantResponseMessage | null) => {
    assistantResponseRef.current = value;
    setAssistantResponseState(value);
  };

  const commitPresentedAssistantResponse = () => {
    const response = assistantResponseRef.current;
    if (response?.state !== "presenting") return;

    console.log();
    console.log(renderAssistantResponse(response, personality));
    setAssistantResponse(null);
  };

  const handleExit = () => {
    console.log("\nBye!");
    exit();
  };

  const handleHistorySaveError = (err: unknown) => {
    console.log(
      `\x1b[31mwarning: failed to save prompt history: ${
        err instanceof Error ? err.message : err
      }\x1b[0m`,
    );
  };

  const renderUserSubmission = (body: string) => {
    commitPresentedAssistantResponse();
    console.log();
    console.log(
      renderConversationMessage(
        {
          speaker: userName,
          body,
          kind: "user",
          timestamp: new Date(),
        },
        personality,
      ),
    );
  };

  const handleComposerSubmit = (submission: PromptComposerSubmission) => {
    if (processingRef.current) return;

    const body =
      submission.kind === "shortcut"
        ? `${submission.shortcutLabel} (${submission.name})`
        : submission.input;

    renderUserSubmission(body);
    setProcessing(true);

    const isCommand =
      submission.kind === "shortcut" || submission.kind === "slash-command";
    if (isCommand) setComposerSuspended(true);

    const run = async () => {
      if (submission.kind === "shortcut") {
        const cmd = commandsRef.current.find((c) => c.name === submission.name);
        if (cmd) {
          setAssistantResponse(null);
          await cmd.action();
        }
        return;
      }

      if (submission.kind === "slash-command") {
        const cmd = commandsRef.current.find((c) => c.name === submission.name);
        if (cmd) {
          setAssistantResponse(null);
          await cmd.action();
        } else {
          setAssistantResponse(null);
          console.log(`\x1b[31mUnknown command: ${trigger}${submission.name}\x1b[0m`);
        }
        return;
      }

      setAssistantResponse({ state: "loading", timestamp: new Date() });
      const responseBody = await onMessage(
        submission.input,
        setAssistantResponse,
      );
      if (typeof responseBody === "string") {
        setAssistantResponse({
          state: "presenting",
          body: responseBody,
          timestamp: new Date(),
        });
      } else {
        setAssistantResponse(null);
      }
    };

    run().finally(() => {
      setProcessing(false);
      if (isCommand) setComposerSuspended(false);
    });
  };

  return (
    <Box flexDirection="column">
      {assistantResponse && (
        <CaliResponse response={assistantResponse} personality={personality} />
      )}
      {!composerSuspended && (
        <PromptComposer
          commands={commands}
          disabled={isProcessing}
          onExit={handleExit}
          onHistorySaveError={handleHistorySaveError}
          onSubmit={handleComposerSubmit}
          trigger={trigger}
        />
      )}
    </Box>
  );
}

export function startPrompt(
  onMessage: (
    input: string,
    updateAssistantResponse: AssistantResponseUpdater,
  ) => Promise<string | void>,
  options?: {
    trigger?: string;
    userName?: string;
    personality?: AssistantPersonality;
    greeting?: string;
  },
  renderOptions?: RenderOptions,
): Prompt {
  const commands: SlashCommand[] = [];

  function makeElement() {
    return (
      <PromptApp
        onMessage={onMessage}
        options={options}
        commands={[...commands]}
      />
    );
  }

  let inst = render(makeElement(), renderOptions);

  return {
    registerSlashCommand(cmd) {
      commands.push(cmd);
      inst.rerender(makeElement());
    },
    pause() {
      inst.clear();
      inst.unmount();
    },
    resume() {
      inst = render(makeElement(), renderOptions);
    },
  };
}
