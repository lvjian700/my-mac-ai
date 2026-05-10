import React from "react";
import { Box, Text } from "ink";
import { formatShortcut } from "./shortcuts.js";
import type { PromptCommandItem } from "./types.js";

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

export function SlashCommandPopup({
  items,
  selectedIndex,
  trigger,
}: {
  items: PromptCommandItem[];
  selectedIndex: number;
  trigger: string;
}) {
  const colWidth =
    items.length > 0 ? Math.max(...items.map((c) => c.name.length)) : 0;

  return (
    <Box flexDirection="column" marginTop={1}>
      {items.map((item, i) => (
        <PopupRow
          key={item.name}
          item={item}
          selected={i === selectedIndex}
          trigger={trigger}
          colWidth={colWidth}
        />
      ))}
    </Box>
  );
}
