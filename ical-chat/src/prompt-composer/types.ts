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

export type PromptComposerSubmission =
  | {
      kind: "message";
      input: string;
    }
  | {
      kind: "slash-command";
      input: string;
      name: string;
    }
  | {
      kind: "shortcut";
      name: string;
      shortcut: KeyShortcut;
      shortcutLabel: string;
    };
