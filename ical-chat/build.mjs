import { build } from "esbuild";
import { readFileSync, chmodSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILL_DIR = join(__dirname, "../ical/.claude/skills/ical");

const skillMd = readFileSync(join(SKILL_DIR, "SKILL.md"), "utf-8");
const rulesMd = readFileSync(
  join(SKILL_DIR, "references/calendar_rules.md"),
  "utf-8"
);

// At build time, intercept the skill-data module and embed file contents
const embedSkillData = {
  name: "embed-skill-data",
  setup(build) {
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

// Replace ink's optional react-devtools integration with a no-op so the
// missing react-devtools-core package doesn't cause a hard import error.
const stubDevtools = {
  name: "stub-devtools",
  setup(build) {
    build.onResolve({ filter: /react-devtools-core/ }, () => ({
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

await build({
  entryPoints: ["src/index.ts"],
  bundle: true,
  platform: "node",
  target: ["node23"],
  format: "esm",
  outfile: "dist/cali",
  plugins: [embedSkillData, stubDevtools],
  jsx: "automatic",
  jsxImportSource: "react",
  banner: {
    js: [
      "#!/usr/bin/env node",
      // Polyfill require() for CJS modules bundled into ESM context
      'import { createRequire } from "module";',
      "const require = createRequire(import.meta.url);",
    ].join("\n"),
  },
});

chmodSync("dist/cali", 0o755);
console.log("Built dist/cali");
