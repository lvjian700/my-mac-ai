import React, { useState, useMemo, useRef, useEffect } from "react";
import { Box, Text, render, useInput, useApp } from "ink";
import {
  renderAssistantResponse,
  renderConversationMessage,
} from "./renderer.js";
import type { AssistantResponseMessage } from "./renderer.js";
import { CALI } from "./personalities/cali.js";
import type { AssistantPersonality } from "./personalities/types.js";
import { formatShortcut, PromptComposer } from "./prompt-composer.js";
import type { KeyShortcut } from "./prompt-composer.js";
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

interface PromptAppProps {
  onMessage: (
    input: string,
    updateAssistantResponse: AssistantResponseUpdater,
  ) => Promise<string | void>;
  options?: {
    trigger?: string;
    userName?: string;
    personality?: AssistantPersonality;
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

function normalizeTextInput(input: string): string {
  return input.replace(/[\r\n]+/g, " ").replace(/[\u0000-\u001f\u007f]/g, "");
}

function PromptApp({ onMessage, options, commands }: PromptAppProps) {
  const trigger = options?.trigger ?? "/";
  const personality = options?.personality ?? CALI;
  const userName = options?.userName ?? "You";
  const { exit } = useApp();

  const [inputBuffer, setInputBuffer] = useState("");
  const [cursorIndex, setCursorIndex] = useState(0);
  const [popupIndex, setPopupIndex] = useState(0);
  const [helpVisible, setHelpVisible] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [assistantResponse, setAssistantResponseState] =
    useState<AssistantResponseMessage | null>(null);
  const processingRef = useRef(false);
  const assistantResponseRef = useRef<AssistantResponseMessage | null>(null);

  const commandsRef = useRef(commands);
  useEffect(() => {
    commandsRef.current = commands;
  }, [commands]);

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

  const popupItems = useMemo(() => {
    if (helpVisible) {
      return commands;
    }

    if (inputBuffer.startsWith(trigger)) {
      const partial = inputBuffer.slice(trigger.length);
      return commands.filter((c) => c.name.startsWith(partial));
    }
    return [];
  }, [commands, helpVisible, inputBuffer, trigger]);

  const popupVisible = popupItems.length > 0;

  useInput(
    (input, key) => {
      if (
        (key.ctrl && input === "c") ||
        (key.ctrl && input === "d" && inputBuffer.length === 0)
      ) {
        console.log("\nBye!");
        exit();
        return;
      }

      if (processingRef.current) return;

      if (input === "?" && inputBuffer.length === 0 && !key.ctrl && !key.meta) {
        setHelpVisible(true);
        setPopupIndex(0);
        return;
      }

      if (key.ctrl && input === "a") {
        setCursorIndex(0);
        return;
      }

      if (key.ctrl && input === "b") {
        setCursorIndex((i) => Math.max(0, i - 1));
        return;
      }

      if (key.ctrl && input === "e") {
        setCursorIndex(inputBuffer.length);
        return;
      }

      if (key.ctrl && input === "f") {
        setCursorIndex((i) => Math.min(inputBuffer.length, i + 1));
        return;
      }

      if (key.ctrl && input === "u") {
        setInputBuffer("");
        setCursorIndex(0);
        setPopupIndex(0);
        setHelpVisible(false);
        return;
      }

      // Keyboard shortcut
      const shortcutCmd = commandsRef.current.find(
        (c) =>
          c.shortcut &&
          c.shortcut.name === input &&
          !!c.shortcut.ctrl === !!key.ctrl &&
          !!c.shortcut.meta === !!key.meta,
      );
      if (shortcutCmd) {
        const hint = formatShortcut(shortcutCmd.shortcut!);
        commitPresentedAssistantResponse();
        console.log();
        console.log(
          renderConversationMessage(
            {
              speaker: userName,
              body: `${hint} (${shortcutCmd.name})`,
              kind: "user",
              timestamp: new Date(),
            },
            personality,
          ),
        );
        setInputBuffer("");
        setCursorIndex(0);
        setHelpVisible(false);
        setAssistantResponse(null);
        setProcessing(true);
        Promise.resolve(shortcutCmd.action()).finally(() => {
          setProcessing(false);
        });
        return;
      }

      if (key.return) {
        const submitted =
          popupVisible && popupItems.length > 0
            ? trigger + popupItems[Math.min(popupIndex, popupItems.length - 1)].name
            : inputBuffer.trim();

        setInputBuffer("");
        setCursorIndex(0);
        setPopupIndex(0);
        setHelpVisible(false);

        if (!submitted) return;

        commitPresentedAssistantResponse();
        console.log();
        console.log(
          renderConversationMessage(
            {
              speaker: userName,
              body: submitted,
              kind: "user",
              timestamp: new Date(),
            },
            personality,
          ),
        );
        setProcessing(true);

        const run = async () => {
          if (submitted.startsWith(trigger)) {
            const cmdName = submitted.slice(trigger.length).split(/\s+/)[0];
            const cmd = commandsRef.current.find((c) => c.name === cmdName);
            if (cmd) {
              setAssistantResponse(null);
              await cmd.action();
            } else {
              setAssistantResponse(null);
              console.log(`\x1b[31mUnknown command: ${trigger}${cmdName}\x1b[0m`);
            }
          } else {
            setAssistantResponse({ state: "loading", timestamp: new Date() });
            const responseBody = await onMessage(
              submitted,
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
          }
        };

        run().finally(() => setProcessing(false));
        return;
      }

      if (key.tab) {
        if (popupVisible && popupItems.length > 0) {
          const completed =
            trigger + popupItems[Math.min(popupIndex, popupItems.length - 1)].name;
          setInputBuffer(completed);
          setCursorIndex(completed.length);
          setPopupIndex(0);
          setHelpVisible(false);
        }
        return;
      }

      if (key.upArrow) {
        if (popupVisible && popupIndex > 0) setPopupIndex((i) => i - 1);
        return;
      }

      if (key.downArrow) {
        if (popupVisible && popupIndex < popupItems.length - 1)
          setPopupIndex((i) => i + 1);
        return;
      }

      if (key.leftArrow) {
        setCursorIndex((i) => Math.max(0, i - 1));
        return;
      }

      if (key.rightArrow) {
        setCursorIndex((i) => Math.min(inputBuffer.length, i + 1));
        return;
      }

      if (key.escape) {
        setInputBuffer("");
        setCursorIndex(0);
        setPopupIndex(0);
        setHelpVisible(false);
        return;
      }

      if (key.backspace || key.delete) {
        if (helpVisible) {
          setHelpVisible(false);
          return;
        }

        if (key.backspace) {
          if (cursorIndex === 0) return;

          setInputBuffer(
            inputBuffer.slice(0, cursorIndex - 1) +
              inputBuffer.slice(cursorIndex),
          );
          setCursorIndex((i) => Math.max(0, i - 1));
          return;
        }

        if (cursorIndex >= inputBuffer.length) return;

        setInputBuffer(
          inputBuffer.slice(0, cursorIndex) +
            inputBuffer.slice(cursorIndex + 1),
        );
        return;
      }

      if (input && !key.ctrl && !key.meta) {
        const text = normalizeTextInput(input);
        if (text.length === 0) return;

        setInputBuffer(
          inputBuffer.slice(0, cursorIndex) +
            text +
            inputBuffer.slice(cursorIndex),
        );
        setCursorIndex((i) => i + text.length);
        setPopupIndex(0);
        setHelpVisible(false);
      }
    },
    { isActive: true },
  );

  return (
    <Box flexDirection="column">
      {assistantResponse && (
        <CaliResponse response={assistantResponse} personality={personality} />
      )}
      <PromptComposer
        cursorIndex={cursorIndex}
        disabled={isProcessing}
        inputBuffer={inputBuffer}
        popupItems={popupItems}
        popupIndex={popupIndex}
        popupVisible={popupVisible}
        trigger={trigger}
      />
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
  },
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

  let inst = render(makeElement());

  return {
    registerSlashCommand(cmd) {
      commands.push(cmd);
      inst.rerender(makeElement());
    },
    pause() {
      inst.unmount();
    },
    resume() {
      inst = render(makeElement());
    },
  };
}
