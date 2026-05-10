import type { KeyShortcut } from "./types.js";

export function formatShortcut(s: KeyShortcut): string {
  if (s.ctrl) return "^" + s.name.toUpperCase();
  if (s.meta) return "M-" + s.name;
  return s.name;
}
