import chalk, { type ChalkInstance } from "chalk";
import wrapAnsi from "wrap-ansi";
import { CALI } from "./personalities/cali.js";
import type { AssistantPersonality } from "./personalities/types.js";

type SpeakerKind = "assistant" | "user";
export type AssistantResponseState = "loading" | "presenting";

export interface ConversationMessage {
  speaker: string;
  body: string;
  kind: SpeakerKind;
  timestamp?: Date;
}

export interface AssistantResponseMessage {
  state: AssistantResponseState;
  body?: string;
  timestamp?: Date;
}

export type ConversationHeader = Omit<ConversationMessage, "body">;

const tokenPattern =
  /(`[^`\n]+`|\*\*[^*\n]+?\*\*|\[[^\]\n]+\]|@[A-Za-z][A-Za-z0-9_.-]*)/g;

function identity(value: string): string {
  return value;
}

function styleToken(token: string, personality: AssistantPersonality): string {
  const theme = personality.conversationTheme;

  if (token.startsWith("`") && token.endsWith("`")) {
    const label = token.slice(1, -1);
    return chalk.bgHex(theme.eventBackground)(theme.eventText(` ${label} `));
  }

  if (token.startsWith("**") && token.endsWith("**")) {
    return theme.emphasis(token.slice(2, -2));
  }

  if (token.startsWith("[") && token.endsWith("]")) {
    return theme.timeRange(token);
  }

  if (token.startsWith("@")) {
    return theme.user(token);
  }

  return token;
}

export function renderInlineSyntax(
  value: string,
  baseStyle: ChalkInstance | ((value: string) => string) = identity,
  personality: AssistantPersonality = CALI,
): string {
  let rendered = "";
  let lastIndex = 0;

  for (const match of value.matchAll(tokenPattern)) {
    const index = match.index ?? 0;
    rendered += baseStyle(value.slice(lastIndex, index));
    rendered += styleToken(match[0], personality);
    lastIndex = index + match[0].length;
  }

  rendered += baseStyle(value.slice(lastIndex));
  return rendered;
}

function renderNudge(
  value: string,
  personality: AssistantPersonality,
): string {
  const theme = personality.conversationTheme;

  return [
    theme.divider("  │ "),
    theme.nudgeLabel(`${personality.nudgeLabel} `),
    renderInlineSyntax(value, theme.muted, personality),
  ].join("");
}

function renderLine(
  line: string,
  personality: AssistantPersonality,
): string {
  const theme = personality.conversationTheme;
  const trimmed = line.trim();
  if (trimmed.length === 0) return "";

  if (trimmed.startsWith(">")) {
    return renderNudge(trimmed.slice(1).trim(), personality);
  }

  if (/^✓(?:\s|$)/.test(trimmed)) {
    return (
      theme.confirmation("✓") +
      renderInlineSyntax(trimmed.slice(1), theme.text, personality)
    );
  }

  return renderInlineSyntax(line, theme.text, personality);
}

function wrapLine(line: string): string {
  const width = Math.max(20, (process.stdout.columns ?? 100) - 4);
  return wrapAnsi(line, width, { hard: false });
}

export function renderConversationBody(
  body: string,
  personality: AssistantPersonality = CALI,
): string {
  return body
    .trim()
    .split(/\r?\n/)
    .map((line) => renderLine(line, personality))
    .map(wrapLine)
    .join("\n")
    .split("\n")
    .map((line) => (line.length > 0 ? "  " + line : line))
    .join("\n");
}

function renderLoadingBody(
  body: string,
  personality: AssistantPersonality,
): string {
  return body
    .trim()
    .split(/\r?\n/)
    .map(wrapLine)
    .join("\n")
    .split("\n")
    .map((line) =>
      line.length > 0
        ? "  " + personality.conversationTheme.muted(line)
        : line,
    )
    .join("\n");
}

function formatTimestamp(date: Date): string {
  return new Intl.DateTimeFormat(undefined, {
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

export function renderConversationHeader(
  speaker: string,
  kind: SpeakerKind,
  timestamp: Date | undefined,
  personality: AssistantPersonality,
): string {
  const normalized = speaker.replace(/^@/, "").toUpperCase();
  const prefix =
    kind === "assistant" ? `${personality.assistantPrefix} ` : "";
  const raw = `${prefix}${normalized} ›`;
  const styled =
    kind === "assistant"
      ? personality.conversationTheme.assistant(raw)
      : personality.conversationTheme.user(raw);

  if (!timestamp) return styled;

  const time = formatTimestamp(timestamp);
  const columns = process.stdout.columns ?? 100;
  const spacing = Math.max(1, columns - raw.length - time.length);

  return (
    styled +
    " ".repeat(spacing) +
    personality.conversationTheme.time(time)
  );
}

export function renderConversationMessage(
  { speaker, body, kind, timestamp }: ConversationMessage,
  personality: AssistantPersonality = CALI,
): string {
  return [
    renderConversationHeader(speaker, kind, timestamp, personality),
    renderConversationBody(body, personality),
  ].join("\n");
}

export function renderAssistantResponse(
  { state, body, timestamp }: AssistantResponseMessage,
  personality: AssistantPersonality = CALI,
): string {
  const header = renderConversationHeader(
    personality.name,
    "assistant",
    timestamp,
    personality,
  );

  if (state === "loading") {
    const loadingBody = body ?? "checking your calendar...";
    return [header, renderLoadingBody(loadingBody, personality)].join("\n");
  }

  return [header, renderConversationBody(body ?? "", personality)].join("\n");
}
