import { useMemo, useState } from "react";
import { useInput } from "ink";
import {
  addPromptHistoryEntry,
  loadPromptHistory,
  savePromptHistory,
  searchPromptHistory,
} from "../prompt-history.js";
import { formatShortcut } from "./shortcuts.js";
import type {
  PromptCommandItem,
  PromptComposerSubmission,
} from "./types.js";

function normalizeTextInput(input: string): string {
  return input.replace(/[\r\n]+/g, " ").replace(/[\u0000-\u001f\u007f]/g, "");
}

interface UsePromptComposerOptions {
  commands: PromptCommandItem[];
  disabled: boolean;
  onExit: () => void;
  onHistorySaveError: (err: unknown) => void;
  onSubmit: (submission: PromptComposerSubmission) => void;
  trigger: string;
}

export function usePromptComposer({
  commands,
  disabled,
  onExit,
  onHistorySaveError,
  onSubmit,
  trigger,
}: UsePromptComposerOptions) {
  const [inputBuffer, setInputBuffer] = useState("");
  const [cursorIndex, setCursorIndex] = useState(0);
  const [promptHistory, setPromptHistory] = useState<string[]>(() =>
    loadPromptHistory(),
  );
  const [historyIndex, setHistoryIndex] = useState<number | null>(null);
  const [historyDraft, setHistoryDraft] = useState("");
  const [historySearchVisible, setHistorySearchVisible] = useState(false);
  const [historySearchQuery, setHistorySearchQuery] = useState("");
  const [historySearchSelectedIndex, setHistorySearchSelectedIndex] =
    useState(0);
  const [historySearchDraft, setHistorySearchDraft] = useState("");
  const [popupIndex, setPopupIndex] = useState(0);
  const [helpVisible, setHelpVisible] = useState(false);

  const setPromptText = (value: string) => {
    setInputBuffer(value);
    setCursorIndex(value.length);
  };

  const resetHistoryNavigation = () => {
    setHistoryIndex(null);
    setHistoryDraft("");
  };

  const closeHistorySearch = () => {
    setHistorySearchVisible(false);
    setHistorySearchQuery("");
    setHistorySearchSelectedIndex(0);
    setHistorySearchDraft("");
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

  const historySearchResults = useMemo(
    () => searchPromptHistory(promptHistory, historySearchQuery, 10),
    [historySearchQuery, promptHistory],
  );

  const activeHistorySearchSelectedIndex = Math.min(
    historySearchSelectedIndex,
    Math.max(0, historySearchResults.length - 1),
  );

  const recordPromptHistory = (submitted: string) => {
    const nextHistory = addPromptHistoryEntry(promptHistory, submitted);
    if (nextHistory === promptHistory) return;

    setPromptHistory(nextHistory);
    try {
      savePromptHistory(nextHistory);
    } catch (err) {
      onHistorySaveError(err);
    }
  };

  const navigatePromptHistory = (direction: "older" | "newer") => {
    if (promptHistory.length === 0) return;

    if (direction === "older") {
      const nextIndex =
        historyIndex === null
          ? promptHistory.length - 1
          : Math.max(0, historyIndex - 1);

      if (historyIndex === null) {
        setHistoryDraft(inputBuffer);
      }

      setHistoryIndex(nextIndex);
      setPromptText(promptHistory[nextIndex]);
      return;
    }

    if (historyIndex === null) return;

    const nextIndex = historyIndex + 1;
    if (nextIndex >= promptHistory.length) {
      setPromptText(historyDraft);
      resetHistoryNavigation();
      return;
    }

    setHistoryIndex(nextIndex);
    setPromptText(promptHistory[nextIndex]);
  };

  const openHistorySearch = () => {
    setHistorySearchVisible(true);
    setHistorySearchQuery("");
    setHistorySearchSelectedIndex(0);
    setHistorySearchDraft(inputBuffer);
    setHelpVisible(false);
    setPopupIndex(0);
    resetHistoryNavigation();
  };

  const acceptHistorySearchSelection = () => {
    const result = historySearchResults[activeHistorySearchSelectedIndex];
    if (result) {
      setPromptText(result.text);
      resetHistoryNavigation();
    }
    closeHistorySearch();
  };

  const cancelHistorySearch = () => {
    setPromptText(historySearchDraft);
    resetHistoryNavigation();
    closeHistorySearch();
  };

  const resetPrompt = () => {
    setInputBuffer("");
    setCursorIndex(0);
    resetHistoryNavigation();
    closeHistorySearch();
    setPopupIndex(0);
    setHelpVisible(false);
  };

  const submitPrompt = () => {
    const submitted =
      popupVisible && popupItems.length > 0
        ? trigger + popupItems[Math.min(popupIndex, popupItems.length - 1)].name
        : inputBuffer.trim();

    resetPrompt();

    if (!submitted) return;

    if (submitted.startsWith(trigger)) {
      const name = submitted.slice(trigger.length).split(/\s+/)[0];
      onSubmit({ kind: "slash-command", input: submitted, name });
      return;
    }

    recordPromptHistory(submitted);
    onSubmit({ kind: "message", input: submitted });
  };

  useInput(
    (input, key) => {
      if (
        (key.ctrl && input === "c") ||
        (key.ctrl && input === "d" && inputBuffer.length === 0)
      ) {
        onExit();
        return;
      }

      if (disabled) return;

      if (historySearchVisible) {
        if (key.ctrl && input === "r") {
          if (historySearchQuery && historySearchResults.length > 0) {
            setHistorySearchSelectedIndex(
              (i) => (i + 1) % historySearchResults.length,
            );
          }
          return;
        }

        if (key.return) {
          acceptHistorySearchSelection();
          return;
        }

        if (key.escape) {
          cancelHistorySearch();
          return;
        }

        if (key.upArrow) {
          if (historySearchResults.length > 0) {
            setHistorySearchSelectedIndex((i) => Math.max(0, i - 1));
          }
          return;
        }

        if (key.downArrow) {
          if (historySearchResults.length > 0) {
            setHistorySearchSelectedIndex((i) =>
              Math.min(historySearchResults.length - 1, i + 1),
            );
          }
          return;
        }

        if (key.backspace || key.delete) {
          setHistorySearchQuery((query) => query.slice(0, -1));
          setHistorySearchSelectedIndex(0);
          return;
        }

        if (input && !key.ctrl && !key.meta) {
          const text = normalizeTextInput(input);
          if (text.length === 0) return;

          setHistorySearchQuery((query) => query + text);
          setHistorySearchSelectedIndex(0);
        }
        return;
      }

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

      if (key.ctrl && input === "r") {
        openHistorySearch();
        return;
      }

      if (key.ctrl && input === "u") {
        setInputBuffer("");
        setCursorIndex(0);
        resetHistoryNavigation();
        setPopupIndex(0);
        setHelpVisible(false);
        return;
      }

      const shortcutCommand = commands.find(
        (c) =>
          c.shortcut &&
          c.shortcut.name === input &&
          !!c.shortcut.ctrl === !!key.ctrl &&
          !!c.shortcut.meta === !!key.meta,
      );
      if (shortcutCommand?.shortcut) {
        resetPrompt();
        onSubmit({
          kind: "shortcut",
          name: shortcutCommand.name,
          shortcut: shortcutCommand.shortcut,
          shortcutLabel: formatShortcut(shortcutCommand.shortcut),
        });
        return;
      }

      if (key.return) {
        submitPrompt();
        return;
      }

      if (key.tab) {
        if (popupVisible && popupItems.length > 0) {
          const completed =
            trigger + popupItems[Math.min(popupIndex, popupItems.length - 1)].name;
          setInputBuffer(completed);
          setCursorIndex(completed.length);
          resetHistoryNavigation();
          setPopupIndex(0);
          setHelpVisible(false);
        }
        return;
      }

      if (key.upArrow) {
        if (popupVisible && popupIndex > 0) setPopupIndex((i) => i - 1);
        if (!popupVisible) navigatePromptHistory("older");
        return;
      }

      if (key.downArrow) {
        if (popupVisible && popupIndex < popupItems.length - 1)
          setPopupIndex((i) => i + 1);
        if (!popupVisible) navigatePromptHistory("newer");
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
        resetPrompt();
        return;
      }

      if (key.backspace || key.delete) {
        if (helpVisible) {
          setHelpVisible(false);
          return;
        }

        if (cursorIndex === 0) return;

        setInputBuffer(
          inputBuffer.slice(0, cursorIndex - 1) + inputBuffer.slice(cursorIndex),
        );
        setCursorIndex((i) => Math.max(0, i - 1));
        resetHistoryNavigation();
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
        resetHistoryNavigation();
        setPopupIndex(0);
        setHelpVisible(false);
      }
    },
    { isActive: true },
  );

  return {
    activeHistorySearchSelectedIndex,
    cursorIndex,
    historySearchItems: historySearchResults.map((result) => result.text),
    historySearchQuery,
    historySearchVisible,
    inputBuffer,
    popupIndex,
    popupItems,
    popupVisible,
  };
}
