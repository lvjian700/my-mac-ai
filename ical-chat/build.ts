import { chmodSync, existsSync, mkdirSync, readFileSync, rmSync, renameSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILL_DIR = join(__dirname, "../ical/.claude/skills/ical");

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

// When building on a machine without a local provider override, stub the module
// so Bun doesn't fail trying to bundle a non-existent file.
const stubLocalProvider = {
  name: "stub-local-provider",
  setup(build: Bun.PluginBuilder) {
    if (!existsSync(join(__dirname, "src/provider.local.ts"))) {
      build.onResolve({ filter: /\/provider\.local\.js$/ }, () => ({
        path: "provider-local-stub",
        namespace: "no-local-provider",
      }));
      build.onLoad({ filter: /.*/, namespace: "no-local-provider" }, () => ({
        contents: "// no local provider override",
        loader: "js",
      }));
    }
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

const result = await Bun.build({
  entrypoints: ["src/index.ts"],
  outdir: "dist",
  target: "bun",
  format: "esm",
  splitting: false,
  plugins: [embedSkillData, stubLocalProvider, stubDevtools],
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
