import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const SKILL_DIR = join(
  dirname(fileURLToPath(import.meta.url)),
  "../../ical/.claude/skills/ical"
);

export const SKILL_MD = readFileSync(join(SKILL_DIR, "SKILL.md"), "utf-8");
export const RULES_MD = readFileSync(
  join(SKILL_DIR, "references/calendar_rules.md"),
  "utf-8"
);
