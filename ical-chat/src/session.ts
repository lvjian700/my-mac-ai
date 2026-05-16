import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import { execSync } from "child_process";
import { SKILL_MD, RULES_MD } from "./skill-data.js";
import { CALI } from "./personalities/cali.js";
import type { AssistantPersonality } from "./personalities/types.js";
import { type SessionMemory, formatSnapshot } from "./session-memory.js";

function stripFrontmatter(content: string): string {
  if (!content.startsWith("---")) return content;
  const end = content.indexOf("\n---", 3);
  return end === -1 ? content : content.slice(end + 4).trimStart();
}

export function buildSystemPrompt(
  userName?: string,
  personality: AssistantPersonality = CALI,
  sessionMemory?: SessionMemory | null,
): string {
  const MEMORY_PATH = join(homedir(), ".my-mac-ai/ical/memory.yaml");

  let userMemory: string;
  if (existsSync(MEMORY_PATH)) {
    userMemory = `# memory: ${MEMORY_PATH}\n${readFileSync(MEMORY_PATH, "utf-8")}`;
  } else {
    userMemory = "# no ical memory found";
  }

  const tz = execSync("date +%Z", { encoding: "utf-8" }).trim();
  const today = new Date().toLocaleDateString("en-CA");

  const sections = [
    stripFrontmatter(SKILL_MD),
    `## ${personality.responseFormatSectionTitle}`,
    personality.responseFormatPrompt,
    "## Calendar Rules Reference",
    RULES_MD,
    "## Loaded Memory",
    userMemory,
    "## Session Context",
    `Today is ${today}. Timezone: ${tz}.${userName ? ` The user's name is ${userName}.` : ""}`,
  ];

  if (sessionMemory) {
    sections.push(formatSnapshot(sessionMemory));
  } else {
    sections.push("## Calendar Snapshot\n\nNo snapshot available — use the calendar tool for all calendar queries.");
  }

  return sections.join("\n\n");
}
