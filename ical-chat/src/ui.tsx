import React, { useState, useMemo, useRef, useEffect } from "react";
import { render, useInput, useApp } from "ink";
import { renderConversationMessage } from "./renderer.js";
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

interface PromptAppProps {
  onMessage: (input: string) => Promise<void>;
  options?: {
    trigger?: string;
    userName?: string;
    personality?: AssistantPersonality;
  };
  commands: SlashCommand[];
}

function PromptApp({ onMessage, options, commands }: PromptAppProps) {
  const trigger = options?.trigger ?? "/";
  const personality = options?.personality ?? CALI;
  const userName = options?.userName ?? "You";
  const { exit } = useApp();

  const [inputBuffer, setInputBuffer] = useState("");
  const [popupIndex, setPopupIndex] = useState(0);
  const [helpVisible, setHelpVisible] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const processingRef = useRef(false);

  const commandsRef = useRef(commands);
  useEffect(() => {
    commandsRef.current = commands;
  }, [commands]);

  const setProcessing = (value: boolean) => {
    processingRef.current = value;
    setIsProcessing(value);
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
        setHelpVisible(false);
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
        setPopupIndex(0);
        setHelpVisible(false);

        if (!submitted) return;

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
              await cmd.action();
            } else {
              console.log(`\x1b[31mUnknown command: ${trigger}${cmdName}\x1b[0m`);
            }
          } else {
            await onMessage(submitted);
          }
        };

        run().finally(() => setProcessing(false));
        return;
      }

      if (key.tab) {
        if (popupVisible && popupItems.length > 0) {
          setInputBuffer(trigger + popupItems[Math.min(popupIndex, popupItems.length - 1)].name);
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

      if (key.escape) {
        setInputBuffer("");
        setPopupIndex(0);
        setHelpVisible(false);
        return;
      }

      if (key.ctrl && input === "u") {
        setInputBuffer("");
        setPopupIndex(0);
        setHelpVisible(false);
        return;
      }

      if (key.backspace || key.delete) {
        if (helpVisible) {
          setHelpVisible(false);
          return;
        }

        setInputBuffer((b) => b.slice(0, -1));
        return;
      }

      if (input && input.length === 1 && !key.ctrl && !key.meta) {
        setInputBuffer((b) => b + input);
        setPopupIndex(0);
        setHelpVisible(false);
      }
    },
    { isActive: true },
  );

  return (
    <PromptComposer
      disabled={isProcessing}
      inputBuffer={inputBuffer}
      popupItems={popupItems}
      popupIndex={popupIndex}
      popupVisible={popupVisible}
      trigger={trigger}
    />
  );
}

export function startPrompt(
  onMessage: (input: string) => Promise<void>,
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
