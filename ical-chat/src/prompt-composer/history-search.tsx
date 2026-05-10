import React from "react";
import { Box, Text } from "ink";

function truncateLine(value: string): string {
  const width = Math.max(20, (process.stdout.columns ?? 80) - 6);
  if (value.length <= width) return value;
  return value.slice(0, Math.max(0, width - 3)) + "...";
}

interface HistorySearchPopupProps {
  items: string[];
  query: string;
  selectedIndex: number;
}

export function HistorySearchPopup({
  items,
  query,
  selectedIndex,
}: HistorySearchPopupProps) {
  return (
    <Box flexDirection="column" marginTop={1}>
      <Box>
        <Text color="#f0a070" bold>
          {"^R "}
        </Text>
        <Text color="#565f89">history search</Text>
        <Text color="#565f89">{": "}</Text>
        <Text>{query}</Text>
      </Box>
      {items.length === 0 && (
        <Box>
          <Text color="#565656">  no matches</Text>
        </Box>
      )}
      {items.map((item, i) => {
        const selected = i === selectedIndex;
        const label = `${selected ? "›" : " "} ${truncateLine(item)}`;

        return (
          <Box key={`${item}-${i}`}>
            <Text
              backgroundColor={selected ? "#1e2030" : undefined}
              color={selected ? "#f0a070" : "#565656"}
              bold={selected}
            >
              {label}
            </Text>
          </Box>
        );
      })}
    </Box>
  );
}
