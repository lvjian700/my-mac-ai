import { execSync } from "child_process";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const SKILL_DIR = join(
  dirname(fileURLToPath(import.meta.url)),
  "../../ical/.claude/skills/ical"
);

function stripFrontmatter(content: string): string {
  if (!content.startsWith("---")) return content;
  const end = content.indexOf("\n---", 3);
  return end === -1 ? content : content.slice(end + 4).trimStart();
}

export function buildSystemPrompt(userName?: string): string {
  const skillMd = readFileSync(join(SKILL_DIR, "SKILL.md"), "utf-8");
  const rulesMd = readFileSync(
    join(SKILL_DIR, "references/calendar_rules.md"),
    "utf-8"
  );

  let memory: string;
  try {
    memory = execSync(join(SKILL_DIR, "scripts/ical-memory"), {
      encoding: "utf-8",
    });
  } catch {
    memory = "# no ical memory found";
  }

  const tz = execSync("date +%Z", { encoding: "utf-8" }).trim();
  const today = new Date().toLocaleDateString("en-CA");

  return [
    stripFrontmatter(skillMd),
    "## Calendar Rules Reference",
    rulesMd,
    "## Loaded Memory",
    memory,
    "## Session Context",
    `Today is ${today}. Timezone: ${tz}.${userName ? ` The user's name is ${userName}.` : ""}`,
  ].join("\n\n");
}
