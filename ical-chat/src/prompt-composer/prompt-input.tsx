import React from "react";
import { Box, Text } from "ink";

const PROMPT_PLACEHOLDER = 'Try "what\'s my week look like?"';
export const USER_BLUE = "#9cdcfe";

export function PromptDivider() {
  const width = Math.max(24, (process.stdout.columns ?? 80) - 1);
  return <Text color="#303030">{"─".repeat(width)}</Text>;
}

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

export function PromptInput({
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

export function PromptLine({
  cursorIndex,
  disabled,
  inputBuffer,
}: {
  cursorIndex: number;
  disabled: boolean;
  inputBuffer: string;
}) {
  return (
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
  );
}
