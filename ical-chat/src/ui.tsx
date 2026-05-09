import React, { useState, useMemo, useRef, useEffect } from "react";
import { render, Box, Text, useInput, useApp } from "ink";
import { renderConversationMessage } from "./renderer.js";
import { CALI } from "./personalities/cali.js";
import type { AssistantPersonality } from "./personalities/types.js";

export interface KeyShortcut {
  ctrl?: boolean;
  meta?: boolean;
  name: string;
}

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

function formatShortcut(s: KeyShortcut): string {
  if (s.ctrl) return "^" + s.name.toUpperCase();
  if (s.meta) return "M-" + s.name;
  return s.name;
}

interface PopupRowProps {
  item: SlashCommand;
  selected: boolean;
  trigger: string;
  colWidth: number;
}

function PopupRow({ item, selected, trigger, colWidth }: PopupRowProps) {
  const cmd = `${trigger}${item.name}`.padEnd(trigger.length + colWidth);
  const hint = item.shortcut ? `  ${formatShortcut(item.shortcut)}` : "";

  if (selected) {
    return (
      <Box>
        <Text backgroundColor="#1e2030" color="#7aa2f7" bold>
          {" " + cmd}
        </Text>
        <Text backgroundColor="#1e2030" dimColor>
          {"  " + item.description}
        </Text>
        <Text backgroundColor="#1e2030" color="#565f89">
          {hint + " "}
        </Text>
      </Box>
    );
  }

  return (
    <Box>
      <Text dimColor>{" " + cmd}</Text>
      <Text dimColor>{"  " + item.description}</Text>
      <Text color="#565f89" dimColor>
        {hint}
      </Text>
    </Box>
  );
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
  const [isProcessing, setIsProcessing] = useState(false);

  const commandsRef = useRef(commands);
  useEffect(() => {
    commandsRef.current = commands;
  }, [commands]);

  const popupItems = useMemo(() => {
    if (inputBuffer.startsWith(trigger)) {
      const partial = inputBuffer.slice(trigger.length);
      return commandsRef.current.filter((c) => c.name.startsWith(partial));
    }
    return [];
  }, [inputBuffer, trigger]);

  const popupVisible = popupItems.length > 0;

  const colWidth = popupVisible
    ? Math.max(...popupItems.map((c) => c.name.length))
    : 0;

  useInput(
    (input, key) => {
      if (isProcessing) return;

      if (
        (key.ctrl && input === "c") ||
        (key.ctrl && input === "d" && inputBuffer.length === 0)
      ) {
        console.log("\nBye!");
        exit();
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
        setIsProcessing(true);
        Promise.resolve(shortcutCmd.action()).finally(() => {
          setIsProcessing(false);
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
        setIsProcessing(true);

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

        run().finally(() => setIsProcessing(false));
        return;
      }

      if (key.tab) {
        if (popupVisible && popupItems.length > 0) {
          setInputBuffer(trigger + popupItems[Math.min(popupIndex, popupItems.length - 1)].name);
          setPopupIndex(0);
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
        return;
      }

      if (key.ctrl && input === "u") {
        setInputBuffer("");
        setPopupIndex(0);
        return;
      }

      if (key.backspace || key.delete) {
        setInputBuffer((b) => b.slice(0, -1));
        return;
      }

      if (input && input.length === 1 && !key.ctrl && !key.meta) {
        setInputBuffer((b) => b + input);
        setPopupIndex(0);
      }
    },
    { isActive: true },
  );

  if (isProcessing) {
    return null;
  }

  return (
    <Box flexDirection="column">
      <Box>
        <Text color="#9cdcfe" bold>
          {userName.toUpperCase()}
        </Text>
        <Text color="#9cdcfe">{" › "}</Text>
        <Text>{inputBuffer}</Text>
      </Box>
      {popupVisible && (
        <Box flexDirection="column">
          {popupItems.map((item, i) => (
            <PopupRow
              key={item.name}
              item={item}
              selected={i === popupIndex}
              trigger={trigger}
              colWidth={colWidth}
            />
          ))}
        </Box>
      )}
    </Box>
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
