import React from "react";
import { Box, Text } from "ink";

export interface KeyShortcut {
  ctrl?: boolean;
  meta?: boolean;
  name: string;
}

export interface PromptCommandItem {
  name: string;
  description: string;
  shortcut?: KeyShortcut;
}

export function formatShortcut(s: KeyShortcut): string {
  if (s.ctrl) return "^" + s.name.toUpperCase();
  if (s.meta) return "M-" + s.name;
  return s.name;
}

interface PopupRowProps {
  item: PromptCommandItem;
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
export const USER_BLUE = "#9cdcfe";

function BoxCursor({
  disabled = false,
  value = " ",
}: {
  disabled?: boolean;
  value?: string;
}) {
  return (
    <Text backgroundColor={disabled ? "#333333" : USER_BLUE} color="#000000">
      {value}
    </Text>
  );
}

function PromptInput({
  cursorIndex,
  disabled = false,
  value,
}: {
  cursorIndex: number;
  disabled?: boolean;
  value: string;
}) {
  if (value.length > 0) {
    const safeCursorIndex = Math.min(Math.max(cursorIndex, 0), value.length);
    const beforeCursor = value.slice(0, safeCursorIndex);
    const cursorValue = value[safeCursorIndex] ?? " ";
    const afterCursor =
      safeCursorIndex < value.length ? value.slice(safeCursorIndex + 1) : "";

    return (
      <>
        <Text color={disabled ? "#565656" : undefined}>{beforeCursor}</Text>
        <BoxCursor disabled={disabled} value={cursorValue} />
        <Text color={disabled ? "#565656" : undefined}>{afterCursor}</Text>
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

interface PromptComposerProps {
  cursorIndex: number;
  disabled?: boolean;
  inputBuffer: string;
  popupItems: PromptCommandItem[];
  popupIndex: number;
  popupVisible: boolean;
  trigger: string;
}

export function PromptComposer({
  cursorIndex,
  disabled = false,
  inputBuffer,
  popupItems,
  popupIndex,
  popupVisible,
  trigger,
}: PromptComposerProps) {
  const activePopupVisible = !disabled && popupVisible;
  const colWidth = activePopupVisible
    ? Math.max(...popupItems.map((c) => c.name.length))
    : 0;

  return (
    <Box flexDirection="column" marginTop={1}>
      <PromptDivider />
      <Box>
        <Text color={disabled ? "#565656" : USER_BLUE} bold>
          {"› "}
        </Text>
        <PromptInput
          cursorIndex={cursorIndex}
          value={inputBuffer}
          disabled={disabled}
        />
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
