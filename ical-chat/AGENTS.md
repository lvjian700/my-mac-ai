# Agent Guide — ical-chat

Terminal multi-turn chat for Apple Calendar. Uses the Anthropic SDK directly (not Claude Code SDK) so the agentic loop is fully owned in code — no permission prompts.

## Build & Run

```bash
bun install          # install dependencies
bun run start        # start the REPL (reads skill files from ../ical/)
bun run typecheck    # type-check source, build script, and tests
bun run test         # run prompt integration tests
```

Requires `ical` binary on PATH (`make install` from `../ical/`).
Requires `ANTHROPIC_API_KEY` in the environment.

## Release & Install

```bash
bun run build              # bundle to dist/cali (Bun executable)
make install               # build + install to ~/.local/bin/cali
PREFIX=/usr/local make install  # install system-wide (requires sudo)
make uninstall             # remove installed binary
```

The bundle is a single self-contained ESM file with all dependencies inlined and a Bun shebang. Skill files (`SKILL.md`, `calendar_rules.md`) are embedded at build time. User memory (`~/.my-mac-ai/ical/memory.yaml`) is read from disk at startup as usual.

## Architecture

**Tech stack:** TypeScript, Bun, `@anthropic-ai/sdk`, `ink` (React for CLIs).

**Data flow:** user input → Anthropic API (claude-sonnet-4-6) → tool calls → `ical` binary → tool results → API → streamed text response → repeat.

**Key files:**

- `src/index.ts` — entry point; agentic turn runner; conversation rendering
- `src/ui.tsx` — Ink prompt shell: assistant response state, slash command registration/execution, processing lifecycle
- `src/prompt-composer.tsx` — stable prompt-composer facade for imports
- `src/prompt-composer/` — prompt input state, keyboard handling, history search UI, slash command popup UI
- `src/session.ts` — builds the system prompt from SKILL.md + calendar_rules.md + ical-memory output + date/TZ; runs once at startup
- `src/tools.ts` — defines `ical` and `write_memory` tools; executes them directly via `execSync`

**Terminal input requirements:**

- The terminal environment is macOS. Implement prompt input like a macOS text field, including macOS keyboard mapping, cursor movement, deletion behavior, and special-key handling.
- Key names reported by Ink may not match the label or convention users expect on macOS; validate behavior against macOS text-field semantics, not just hook field names.
- Cover terminal editing changes with integration tests that send the real escape/control bytes for the expected macOS user action.

**System prompt sources** (all from `../ical/.claude/skills/ical/`):

- `SKILL.md` — canonical skill instructions (YAML frontmatter stripped)
- `references/calendar_rules.md` — memory capture/apply rules
- `scripts/ical-memory` — prints `~/.my-mac-ai/ical/memory.yaml` if it exists

**Prompt caching:** system prompt is sent with `cache_control: { type: "ephemeral" }` so repeated tool-use continuation calls within the same session hit the cache.

**Memory:** `write_memory` tool writes to `~/.my-mac-ai/ical/memory.yaml`. Memory is loaded once at session startup; if a habit is saved mid-session, it applies from the next turn onward.
