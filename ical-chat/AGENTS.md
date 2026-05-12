# Agent Guide — ical-chat

Terminal multi-turn chat for Apple Calendar. Uses OpenAI Realtime directly so the agentic loop is fully owned in code — no permission prompts.

## Build & Run

```bash
bun install          # install dependencies
bun run start        # start the REPL (reads skill files from ../ical/)
bun run start -- --voice  # start native macOS voice mode
bun run typecheck    # type-check source, build script, and tests
bun run test         # run prompt integration tests
```

Requires `ical` binary on PATH (`make install` from `../ical/`).
Requires `OPENAI_API_KEY` in the environment. Voice mode builds and launches the Swift `native/voice-audio` helper, which uses AVFoundation for microphone capture and audio playback.

## Release & Install

```bash
bun run build              # bundle to dist/cali (Bun executable)
make install               # build + install to ~/.local/bin/cali
PREFIX=/usr/local make install  # install system-wide (requires sudo)
make uninstall             # remove installed binary
```

The bundle is a single self-contained ESM file with all dependencies inlined and a Bun shebang. Skill files (`SKILL.md`, `calendar_rules.md`) are embedded at build time. User memory (`~/.my-mac-ai/ical/memory.yaml`) is read from disk at startup as usual. `make install` also installs the Swift voice audio helper to `$(PREFIX)/libexec/cali/cali-voice-audio`.

## Architecture

**Tech stack:** TypeScript, Bun, OpenAI Realtime WebSocket, `ink` (React for CLIs), Swift/AVFoundation for native voice audio.

**Text data flow:** user input → Realtime API (`gpt-realtime-2`) → tool calls → `ical` binary → tool results → API → streamed text response → repeat.

**Voice data flow:** `cali --voice` → Swift AVFoundation helper → Realtime WebSocket audio events → tool calls → `ical` binary → spoken audio response. Voice mode exits after 60 seconds with no user speech, assistant output, tool activity, or terminal input.

**Key files:**

- `src/index.ts` — entry point; selects text mode or `--voice`
- `src/text-chat.ts` — text-mode Realtime runner and slash commands
- `src/realtime/` — shared Realtime session, event handling, and tool adapter
- `src/voice/` — voice-mode runner, idle timeout, and Swift audio bridge
- `native/voice-audio/` — SwiftPM AVFoundation helper for mic capture/playback
- `src/ui.tsx` — Ink prompt shell: assistant response state, slash command registration/execution, processing lifecycle
- `src/prompt-composer.tsx` — stable prompt-composer facade for imports
- `src/prompt-composer/` — prompt input state, keyboard handling, history search UI, slash command popup UI
- `src/session.ts` — builds the system prompt from SKILL.md + calendar_rules.md + ical-memory output + date/TZ; runs once at startup
- `src/tools.ts` — defines provider-neutral `ical` and `write_memory` tools; executes them directly via `execSync`

**Terminal input requirements:**

- The terminal environment is macOS. Implement prompt input like a macOS text field, including macOS keyboard mapping, cursor movement, deletion behavior, and special-key handling.
- Key names reported by Ink may not match the label or convention users expect on macOS; validate behavior against macOS text-field semantics, not just hook field names.
- Cover terminal editing changes with integration tests that send the real escape/control bytes for the expected macOS user action.

**System prompt sources** (all from `../ical/.claude/skills/ical/`):

- `SKILL.md` — canonical skill instructions (YAML frontmatter stripped)
- `references/calendar_rules.md` — memory capture/apply rules
- `scripts/ical-memory` — prints `~/.my-mac-ai/ical/memory.yaml` if it exists

**Realtime config:** defaults to `CALI_REALTIME_MODEL=gpt-realtime-2`, `CALI_REALTIME_REASONING_EFFORT=medium`, and `CALI_VOICE=marin` unless overridden.

**Memory:** `write_memory` tool writes to `~/.my-mac-ai/ical/memory.yaml`. Memory is loaded once at session startup; if a habit is saved mid-session, it applies from the next turn onward.
