# Agent Guide — ical-chat

Terminal multi-turn chat for Apple Calendar. Uses the Anthropic SDK directly (not Claude Code SDK) so the agentic loop is fully owned in code — no permission prompts.

## Build & Run

```bash
npm install          # install dependencies
npm start            # start the REPL (dev mode, reads skill files from ../ical/)
```

Requires `ical` binary on PATH (`make install` from `../ical/`).
Requires `ANTHROPIC_API_KEY` in the environment.

## Release & Install

```bash
npm run build              # bundle to dist/cali (standalone binary, ~4 MB)
make install               # build + install to /usr/local/bin/cali
PREFIX=~/.local make install  # install to a custom prefix
make uninstall             # remove installed binary
```

The bundle is a single self-contained ESM file with all dependencies inlined. Skill files (`SKILL.md`, `calendar_rules.md`) are embedded at build time. User memory (`~/.my-mac-ai/ical/memory.yaml`) is read from disk at startup as usual.

## Architecture

**Tech stack:** TypeScript, Node.js 23+, `@anthropic-ai/sdk`, `ink` (React for CLIs).

**Data flow:** user input → Anthropic API (claude-sonnet-4-6) → tool calls → `ical` binary → tool results → API → streamed text response → repeat.

**Key files:**

- `src/index.ts` — entry point; agentic turn runner; markdown rendering
- `src/ui.tsx` — Ink-based interactive prompt: input buffer, slash command popup, keyboard handling
- `src/session.ts` — builds the system prompt from SKILL.md + calendar_rules.md + ical-memory output + date/TZ; runs once at startup
- `src/tools.ts` — defines `ical` and `write_memory` tools; executes them directly via `execSync`

**System prompt sources** (all from `../ical/.claude/skills/ical/`):

- `SKILL.md` — canonical skill instructions (YAML frontmatter stripped)
- `references/calendar_rules.md` — memory capture/apply rules
- `scripts/ical-memory` — prints `~/.my-mac-ai/ical/memory.yaml` if it exists

**Prompt caching:** system prompt is sent with `cache_control: { type: "ephemeral" }` so repeated tool-use continuation calls within the same session hit the cache.

**Memory:** `write_memory` tool writes to `~/.my-mac-ai/ical/memory.yaml`. Memory is loaded once at session startup; if a habit is saved mid-session, it applies from the next turn onward.
