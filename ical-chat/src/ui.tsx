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

function PromptDivider() {
  const width = Math.max(24, (process.stdout.columns ?? 80) - 1);
  return <Text color="#303030">{"─".repeat(width)}</Text>;
}

const PROMPT_PLACEHOLDER = 'Try "what\'s my week look like?"';
const USER_BLUE = "#9cdcfe";

function BoxCursor({ disabled = false }: { disabled?: boolean }) {
  return (
    <Text backgroundColor={disabled ? "#333333" : USER_BLUE} color="#000000">
      {" "}
    </Text>
  );
}

function PromptInput({
  disabled = false,
  value,
}: {
  disabled?: boolean;
  value: string;
}) {
  if (value.length > 0) {
    return (
      <>
        <Text color={disabled ? "#565656" : undefined}>{value}</Text>
        <BoxCursor disabled={disabled} />
      </>
    );
  }

  return (
    <>
      <BoxCursor disabled={disabled} />
      <Text color="#565656">{PROMPT_PLACEHOLDER}</Text>
    </>
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

  const colWidth = popupVisible
    ? Math.max(...popupItems.map((c) => c.name.length))
    : 0;

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

  const inputDisabled = isProcessing;
  const activePopupVisible = !inputDisabled && popupVisible;

  return (
    <Box flexDirection="column" marginTop={1}>
      <PromptDivider />
      <Box>
        <Text color={inputDisabled ? "#565656" : USER_BLUE} bold>
          {"› "}
        </Text>
        <PromptInput value={inputBuffer} disabled={inputDisabled} />
      </Box>
      <PromptDivider />
      {!activePopupVisible && (
        <Box>
          <Text color="#565656">? for help</Text>
        </Box>
      )}
      {activePopupVisible && (
        <Box flexDirection="column" marginTop={1}>
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
