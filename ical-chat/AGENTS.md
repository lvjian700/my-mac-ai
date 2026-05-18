# Agent Guide — ical-chat

Terminal multi-turn chat for Apple Calendar. Uses the Anthropic API directly so the agentic loop is fully owned in code — no permission prompts.

## Build & Run

```bash
bun install          # install dependencies
bun run start        # start the REPL (reads skill files from ../ical/)
bun run start -- --debug  # start with API/tool debug logs on stderr
bun run sync         # refresh session-memory.json every 2 minutes
bun run typecheck    # type-check source, build script, and tests
bun run test         # run unit/prompt tests
bun run test:integration  # run Calendar integration tests against real ical + ~/.my-mac-ai
```

Requires `ical` binary on PATH (`make install` from `../ical/`).
Requires `ANTHROPIC_API_KEY` in the environment.

## Release & Install

```bash
bun run build              # bundle to dist/cali (Bun executable)
make install               # build + install to ~/.local/bin/cali
PREFIX=/usr/local make install  # install system-wide (requires sudo)
make sync                  # run the Calendar Snapshot refresh daemon
make uninstall             # remove installed binary
```

The bundle is a single self-contained ESM file with all dependencies inlined and a Bun shebang. Skill files (`SKILL.md`, `calendar_rules.md`) are embedded at build time. User memory (`~/.my-mac-ai/ical/memory.yaml`) is read from disk at startup as usual.

## Architecture

**Tech stack:** TypeScript, Bun, Anthropic Messages API (streaming), `ink` (React for CLIs).

**Data flow:** user input → `ChatSession` (claude-sonnet-4-6, streaming) → `calendar` tool → `runICalAgent` (claude-haiku-4-5-20251001, one-shot) → `ical` binary → result → orchestrator response → repeat.

**Two-agent design:**

- **Orchestrator** (`claude-sonnet-4-6`) — handles conversation, reads the Calendar Snapshot from system prompt, calls `calendar` tool for anything outside the snapshot window or mutations.
- **iCal sub-agent** (`claude-haiku-4-5-20251001`) — has only the `ical` tool; runs a tool-calling loop until done; returns a concise factual summary. Never speaks to the user directly. The `## Commands` section of `SKILL.md` is injected into its system prompt so it has the correct CLI flags at call time.

This split eliminates preamble narration ("One sec…", "Checking your calendar…") from the orchestrator's final response.

**Key files:**

- `src/index.ts` — entry point
- `src/text-chat.ts` — session runner and slash commands
- `src/chat-session.ts` — `ChatSession` class: streaming Messages API, client-side message history, tool-call loop
- `src/ical-agent.ts` — `runICalAgent()`: haiku sub-agent with `ical` tool only
- `src/tools.ts` — `calendar` and `write_memory` tool definitions (Anthropic format) + async `executeTool`
- `src/ui.tsx` — Ink prompt shell: assistant response state, slash command registration/execution, processing lifecycle
- `src/prompt-composer.tsx` — stable prompt-composer facade for imports
- `src/prompt-composer/` — prompt input state, keyboard handling, history search UI, slash command popup UI
- `src/session.ts` — builds the system prompt from SKILL.md + calendar_rules.md + ical-memory output + date/TZ; runs once at startup
- `src/session-memory.ts` — Calendar Snapshot: `buildSessionMemory`, `readSessionMemory`, `diffEvents`, `formatSnapshot`, `formatMemoryUpdate`
- `scripts/cali-sync.ts` — background daemon that refreshes `~/.my-mac-ai/ical/session-memory.json` every 2 minutes

**Terminal input requirements:**

- The terminal environment is macOS. Implement prompt input like a macOS text field, including macOS keyboard mapping, cursor movement, deletion behavior, and special-key handling.
- Key names reported by Ink may not match the label or convention users expect on macOS; validate behavior against macOS text-field semantics, not just hook field names.
- Cover terminal editing changes with integration tests that send the real escape/control bytes for the expected macOS user action.

**System prompt sources** (all from `../ical/.claude/skills/ical/`):

- `SKILL.md` — canonical skill instructions (YAML frontmatter stripped)
- `references/calendar_rules.md` — memory capture/apply rules
- `scripts/ical-memory` — prints `~/.my-mac-ai/ical/memory.yaml` if it exists

**Session Memory (Calendar Snapshot):**

- On startup, `buildSessionMemory()` fetches the current week + next week from `ical` and writes `~/.my-mac-ai/ical/session-memory.json`.
- The snapshot is embedded in the system prompt so the orchestrator can answer common date-range questions without a tool call.
- `bun run sync` / `make sync` runs `scripts/cali-sync.ts`, a long-running daemon that refreshes the snapshot file every 2 minutes.
- During chat, a `setInterval` (60 s) polls the file for daemon-written updates and queues a `SessionMemoryUpdate` diff, injected as a context message before the next user turn.

**Memory:** `write_memory` tool writes to `~/.my-mac-ai/ical/memory.yaml`. Memory is loaded once at session startup; if a habit is saved mid-session, it applies from the next turn onward.

**Provider overrides:**

By default the app uses the Anthropic API directly (`ANTHROPIC_API_KEY`). To swap in a different provider (e.g. AWS Bedrock) on a specific machine without touching committed files, create `src/provider.local.ts`. This file is gitignored and never pushed to the remote.

`src/provider.local.ts` must export a single `createProvider()` function that returns a `Provider`:

```typescript
import AnthropicBedrock from "@anthropic-ai/bedrock-sdk";
import type { Provider } from "./provider.js";

export function createProvider(): Provider {
  return {
    client: new AnthropicBedrock() as unknown as import("@anthropic-ai/sdk").default,
    orchestratorModel: "us.anthropic.claude-sonnet-4-6-v1:0",
    subAgentModel: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
  };
}
```

When the file is absent, `getProvider()` in `src/provider.ts` falls back to the default Anthropic client. The build system (`build.ts`) stubs the missing module automatically, so `bun run build` works on machines without a local override.

**Debug flags:**

- `--debug` — CLI flag equivalent to `CALI_DEBUG=1`
- `CALI_DEBUG=1` — log API send/recv events to stderr
- `CALI_DEBUG_MESSAGES=1` — append raw user/assistant messages to `~/.my-mac-ai/ical/messages.jsonl`
