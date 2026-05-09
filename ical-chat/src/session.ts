import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import { execSync } from "child_process";
import { SKILL_MD, RULES_MD } from "./skill-data.js";
import { CALI } from "./personalities/cali.js";
import type { AssistantPersonality } from "./personalities/types.js";

function stripFrontmatter(content: string): string {
  if (!content.startsWith("---")) return content;
  const end = content.indexOf("\n---", 3);
  return end === -1 ? content : content.slice(end + 4).trimStart();
}

export function buildSystemPrompt(
  userName?: string,
  personality: AssistantPersonality = CALI,
): string {
  const MEMORY_PATH = join(homedir(), ".my-mac-ai/ical/memory.yaml");

  let memory: string;
  if (existsSync(MEMORY_PATH)) {
    memory = `# memory: ${MEMORY_PATH}\n${readFileSync(MEMORY_PATH, "utf-8")}`;
  } else {
    memory = "# no ical memory found";
  }

  const tz = execSync("date +%Z", { encoding: "utf-8" }).trim();
  const today = new Date().toLocaleDateString("en-CA");

  return [
    stripFrontmatter(SKILL_MD),
    `## ${personality.responseFormatSectionTitle}`,
    personality.responseFormatPrompt,
    "## Calendar Rules Reference",
    RULES_MD,
    "## Loaded Memory",
    memory,
    "## Session Context",
    `Today is ${today}. Timezone: ${tz}.${userName ? ` The user's name is ${userName}.` : ""}`,
  ].join("\n\n");
}
