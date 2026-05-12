import { chmodSync, mkdirSync, readFileSync, rmSync, renameSync } from "node:fs";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILL_DIR = join(__dirname, "../ical/.claude/skills/ical");
const VOICE_AUDIO_DIR = join(__dirname, "native/voice-audio");

const skillMd = readFileSync(join(SKILL_DIR, "SKILL.md"), "utf-8");
const rulesMd = readFileSync(
  join(SKILL_DIR, "references/calendar_rules.md"),
  "utf-8",
);

const embedSkillData = {
  name: "embed-skill-data",
  setup(build: Bun.PluginBuilder) {
    build.onResolve({ filter: /\/skill-data\.js$/ }, () => ({
      path: "skill-data",
      namespace: "embedded",
    }));
    build.onLoad({ filter: /.*/, namespace: "embedded" }, () => ({
      contents: `
        export const SKILL_MD = ${JSON.stringify(skillMd)};
        export const RULES_MD = ${JSON.stringify(rulesMd)};
      `,
      loader: "js",
    }));
  },
};

const stubDevtools = {
  name: "stub-devtools",
  setup(build: Bun.PluginBuilder) {
    build.onResolve({ filter: /^react-devtools-core$/ }, () => ({
      path: "react-devtools-core",
      namespace: "stub",
    }));
    build.onLoad({ filter: /.*/, namespace: "stub" }, () => ({
      contents: "export default {};",
      loader: "js",
    }));
  },
};

mkdirSync("dist", { recursive: true });
rmSync("dist/cali", { force: true });

const swiftBuild = spawnSync("swift", ["build", "-c", "release"], {
  cwd: VOICE_AUDIO_DIR,
  stdio: "inherit",
});
if (swiftBuild.status !== 0) {
  process.exit(swiftBuild.status ?? 1);
}

const result = await Bun.build({
  entrypoints: ["src/index.ts"],
  outdir: "dist",
  target: "bun",
  format: "esm",
  splitting: false,
  plugins: [embedSkillData, stubDevtools],
  jsx: {
    runtime: "automatic",
    importSource: "react",
  },
  banner: "#!/usr/bin/env bun",
});

if (!result.success) {
  for (const log of result.logs) {
    console.error(log);
  }
  process.exit(1);
}

renameSync("dist/index.js", "dist/cali");
chmodSync("dist/cali", 0o755);
console.log("Built dist/cali");
