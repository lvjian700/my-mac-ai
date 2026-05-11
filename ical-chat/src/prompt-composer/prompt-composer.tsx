import React from "react";
import { Box, Text } from "ink";
import { HistorySearchPopup } from "./history-search.js";
import { PromptDivider, PromptLine } from "./prompt-input.js";
import { SlashCommandPopup } from "./slash-commands.js";
import { usePromptComposer } from "./use-prompt-composer.js";
import type {
  PromptCommandItem,
  PromptComposerSubmission,
} from "./types.js";

interface PromptComposerProps {
  commands: PromptCommandItem[];
  disabled?: boolean;
  onExit: () => void;
  onHistorySaveError: (err: unknown) => void;
  onSubmit: (submission: PromptComposerSubmission) => void;
  trigger: string;
}

export function PromptComposer({
  commands,
  disabled = false,
  onExit,
  onHistorySaveError,
  onSubmit,
  trigger,
}: PromptComposerProps) {
  const state = usePromptComposer({
    commands,
    disabled,
    onExit,
    onHistorySaveError,
    onSubmit,
    trigger,
  });
  const activeHistorySearchVisible = !disabled && state.historySearchVisible;
  const activePopupVisible =
    !activeHistorySearchVisible && !disabled && state.popupVisible;

  if (state.submitting) {
    return null;
  }

  return (
    <Box flexDirection="column" marginTop={1}>
      <PromptDivider />
      <PromptLine
        cursorIndex={state.cursorIndex}
        disabled={disabled}
        inputBuffer={state.inputBuffer}
      />
      <PromptDivider />
      {!activeHistorySearchVisible && !activePopupVisible && (
        <Box>
          <Text color="#565656">? for help</Text>
        </Box>
      )}
      {activeHistorySearchVisible && (
        <HistorySearchPopup
          items={state.historySearchItems}
          query={state.historySearchQuery}
          selectedIndex={state.activeHistorySearchSelectedIndex}
        />
      )}
      {activePopupVisible && (
        <SlashCommandPopup
          items={state.popupItems}
          selectedIndex={state.popupIndex}
          trigger={trigger}
        />
      )}
    </Box>
  );
}
