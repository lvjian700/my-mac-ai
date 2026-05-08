import * as readline from "readline";
import chalk from "chalk";

export interface KeyShortcut {
  ctrl?: boolean;
  meta?: boolean;
  name: string;
}

export interface SlashCommand {
  name: string;
  description: string;
  shortcut?: KeyShortcut;
  action: () => void | Promise<void>;
}

function formatShortcut(s: KeyShortcut): string {
  if (s.ctrl) return "^" + s.name.toUpperCase();
  if (s.meta) return "M-" + s.name;
  return s.name;
}

export interface Prompt {
  registerSlashCommand(cmd: SlashCommand): void;
}

const DIM = "\x1b[2m";
const RST = "\x1b[0m";

export function startPrompt(
  onMessage: (input: string) => Promise<void>,
  options?: { trigger?: string; userName?: string },
): Prompt {
  const trigger = options?.trigger ?? "/";
  const userLabel = `@${options?.userName ?? "You"}`;
  const commands: SlashCommand[] = [];

  let inputBuffer = "";
  let popupIndex = 0;
  let popupItems: SlashCommand[] = [];
  let popupVisible = false;
  let isProcessing = false;

  const GREEN_PROMPT = chalk.hex("#9ece6a")("›") + " ";
  const PROMPT_COLS = 2; // visual width of "› "

  function updatePopupState() {
    if (inputBuffer.startsWith(trigger)) {
      const partial = inputBuffer.slice(trigger.length);
      popupItems = commands.filter((c) => c.name.startsWith(partial));
      popupVisible = popupItems.length > 0;
      popupIndex = popupVisible
        ? Math.min(popupIndex, popupItems.length - 1)
        : 0;
    } else {
      popupItems = [];
      popupVisible = false;
      popupIndex = 0;
    }
  }

  function render() {
    // Go to col 0, erase to end of screen, redraw prompt + input
    process.stdout.write(`\r\x1b[J${GREEN_PROMPT}${inputBuffer}`);

    if (popupVisible && popupItems.length > 0) {
      const colWidth = Math.max(...popupItems.map((c) => c.name.length));
      for (let i = 0; i < popupItems.length; i++) {
        const { name, description } = popupItems[i];
        const sel = i === popupIndex;
        const cmd = `${trigger}${name}`.padEnd(trigger.length + colWidth);
        const hint = popupItems[i].shortcut
          ? `  ${formatShortcut(popupItems[i].shortcut!)}`
          : "";
        const line = sel
          ? " " +
            chalk.bgHex("#1e2030").hex("#7aa2f7").bold(cmd) +
            chalk.bgHex("#1e2030").dim(`  ${description}`) +
            chalk.bgHex("#1e2030").hex("#565f89")(hint + " ")
          : " " +
            chalk.dim(cmd) +
            chalk.dim(`  ${description}`) +
            chalk.hex("#565f89").dim(hint);
        process.stdout.write(`\r\n${line}`);
      }
      // Move cursor back up to prompt line
      process.stdout.write(`\x1b[${popupItems.length}A`);
    }

    // Park cursor at end of input
    process.stdout.write(`\r\x1b[${PROMPT_COLS + inputBuffer.length}C`);
  }

  function showPrompt() {
    process.stdout.write(`\n${DIM}${userLabel}${RST}\n`);
    inputBuffer = "";
    popupVisible = false;
    popupItems = [];
    popupIndex = 0;
    render();
  }

  readline.emitKeypressEvents(process.stdin);
  if (process.stdin.isTTY) process.stdin.setRawMode(true);

  process.stdin.on(
    "keypress",
    async (
      str: string | undefined,
      key: { name?: string; ctrl?: boolean; meta?: boolean },
    ) => {
      if (!key || isProcessing) return;

      if (
        (key.ctrl && key.name === "c") ||
        (key.ctrl && key.name === "d" && inputBuffer.length === 0)
      ) {
        process.stdout.write("\nBye!\n");
        process.exit(0);
      }

      // Keyboard shortcut — run matching command immediately
      const shortcutCmd = commands.find(
        (c) =>
          c.shortcut &&
          c.shortcut.name === key.name &&
          !!c.shortcut.ctrl === !!key.ctrl &&
          !!c.shortcut.meta === !!key.meta,
      );
      if (shortcutCmd) {
        const hint = formatShortcut(shortcutCmd.shortcut!);
        process.stdout.write(
          `\r\x1b[J${GREEN_PROMPT}${hint} (${shortcutCmd.name})\n`,
        );
        inputBuffer = "";
        popupVisible = false;
        popupItems = [];
        isProcessing = true;
        try {
          await shortcutCmd.action();
        } finally {
          isProcessing = false;
        }
        showPrompt();
        return;
      }

      if (key.name === "return") {
        const submitted =
          popupVisible && popupItems.length > 0
            ? trigger + popupItems[popupIndex].name
            : inputBuffer.trim();

        inputBuffer = "";
        popupVisible = false;
        popupItems = [];

        if (!submitted) {
          render();
          return;
        }

        // Echo submitted input and advance past popup area
        process.stdout.write(`\r\x1b[J${GREEN_PROMPT}${submitted}\n`);

        isProcessing = true;
        try {
          if (submitted.startsWith(trigger)) {
            const cmdName = submitted.slice(trigger.length).split(/\s+/)[0];
            const cmd = commands.find((c) => c.name === cmdName);
            if (cmd) {
              await cmd.action();
            } else {
              process.stdout.write(
                `\x1b[31mUnknown command: ${trigger}${cmdName}\x1b[0m\n`,
              );
            }
          } else {
            await onMessage(submitted);
          }
        } finally {
          isProcessing = false;
        }
        showPrompt();
        return;
      }

      // Tab — autocomplete selected popup item
      if (key.name === "tab") {
        if (popupVisible && popupItems.length > 0) {
          inputBuffer = trigger + popupItems[popupIndex].name;
          popupVisible = false;
          popupItems = [];
          render();
        }
        return;
      }

      // Arrow up / down — navigate popup
      if (key.name === "up") {
        if (popupVisible && popupIndex > 0) {
          popupIndex--;
          render();
        }
        return;
      }
      if (key.name === "down") {
        if (popupVisible && popupIndex < popupItems.length - 1) {
          popupIndex++;
          render();
        }
        return;
      }

      // Escape — dismiss popup
      if (key.name === "escape") {
        if (popupVisible) {
          popupVisible = false;
          popupItems = [];
          render();
        }
        return;
      }

      // Ctrl+U — clear line
      if (key.ctrl && key.name === "u") {
        inputBuffer = "";
        updatePopupState();
        render();
        return;
      }

      // Backspace / Delete
      if (key.name === "backspace" || key.name === "delete") {
        if (inputBuffer.length > 0) {
          inputBuffer = inputBuffer.slice(0, -1);
          updatePopupState();
          render();
        }
        return;
      }

      // Printable character
      if (str && str.length === 1 && !key.ctrl && !key.meta) {
        inputBuffer += str;
        updatePopupState();
        render();
      }
    },
  );

  showPrompt();

  return {
    registerSlashCommand(cmd: SlashCommand) {
      commands.push(cmd);
    },
  };
}
