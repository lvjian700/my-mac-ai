import type { ChalkInstance } from "chalk";

export interface ConversationTheme {
  assistant: ChalkInstance;
  user: ChalkInstance;
  time: ChalkInstance;
  text: ChalkInstance;
  muted: ChalkInstance;
  divider: ChalkInstance;
  emphasis: ChalkInstance;
  eventText: ChalkInstance;
  eventBackground: string;
  timeRange: ChalkInstance;
  confirmation: ChalkInstance;
  nudgeLabel: ChalkInstance;
}

export interface PromptTheme {
  assistantStar: string;
  assistantName: string;
  assistantCaret: string;
}

export interface AssistantPersonality {
  name: string;
  responseFormatSectionTitle: string;
  responseFormatPrompt: string;
  conversationTheme: ConversationTheme;
  promptTheme: PromptTheme;
  assistantPrefix: string;
  nudgeLabel: string;
}
