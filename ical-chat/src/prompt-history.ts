import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { homedir } from "os";
import { dirname, join } from "path";

export const PROMPT_HISTORY_LIMIT = 500;
export const PROMPT_HISTORY_PATH = join(
  homedir(),
  ".my-mac-ai/ical/history.jsonl",
);

export interface PromptHistoryEntry {
  text: string;
  createdAt: string;
}

export interface PromptHistorySearchResult {
  text: string;
  index: number;
  score: number;
}

function parsePromptHistoryLine(line: string): PromptHistoryEntry | null {
  try {
    const value = JSON.parse(line) as Partial<PromptHistoryEntry>;
    if (typeof value.text !== "string") return null;
    if (typeof value.createdAt !== "string") return null;
    return { text: value.text, createdAt: value.createdAt };
  } catch {
    return null;
  }
}

export function loadPromptHistory(
  path: string = PROMPT_HISTORY_PATH,
): string[] {
  if (!existsSync(path)) return [];

  try {
    return readFileSync(path, "utf-8")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0)
      .map(parsePromptHistoryLine)
      .filter((entry): entry is PromptHistoryEntry => entry !== null)
      .map((entry) => entry.text)
      .slice(-PROMPT_HISTORY_LIMIT);
  } catch {
    return [];
  }
}

export function addPromptHistoryEntry(
  history: string[],
  text: string,
): string[] {
  const trimmed = text.trim();
  if (!trimmed) return history;
  if (history[history.length - 1] === trimmed) return history;

  return [...history, trimmed].slice(-PROMPT_HISTORY_LIMIT);
}

export function savePromptHistory(
  history: string[],
  path: string = PROMPT_HISTORY_PATH,
): void {
  mkdirSync(dirname(path), { recursive: true });

  const now = new Date().toISOString();
  const entries = history.slice(-PROMPT_HISTORY_LIMIT).map((text) =>
    JSON.stringify({
      text,
      createdAt: now,
    } satisfies PromptHistoryEntry),
  );

  writeFileSync(path, entries.join("\n") + (entries.length > 0 ? "\n" : ""));
}

function fuzzyScore(text: string, query: string): number | null {
  const normalizedText = text.toLowerCase();
  const normalizedQuery = query.toLowerCase().trim();
  if (!normalizedQuery) return 0;

  let textIndex = 0;
  let firstMatch = -1;
  let lastMatch = -1;
  let gaps = 0;

  for (const char of normalizedQuery) {
    const matchIndex = normalizedText.indexOf(char, textIndex);
    if (matchIndex === -1) return null;

    if (firstMatch === -1) {
      firstMatch = matchIndex;
    } else {
      gaps += matchIndex - lastMatch - 1;
    }

    lastMatch = matchIndex;
    textIndex = matchIndex + 1;
  }

  return firstMatch + gaps + (lastMatch - firstMatch);
}

export function searchPromptHistory(
  history: string[],
  query: string,
  limit = 10,
): PromptHistorySearchResult[] {
  return history
    .map((text, index) => {
      const score = fuzzyScore(text, query);
      return score === null ? null : { text, index, score };
    })
    .filter(
      (result): result is PromptHistorySearchResult => result !== null,
    )
    .sort((a, b) => a.score - b.score || b.index - a.index)
    .slice(0, limit);
}
