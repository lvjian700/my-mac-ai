# Calendar Rules Memory

Calendar rules are **personalized memory**: the user tells you a habit once, you save it, and apply it automatically on every matching event.

Two moments in the workflow:

1. **Capture** — user describes a habit → derive a rule and save it to memory.
2. **Apply** — event query returns results → load memory, match rules, take action.

## Files

- Memory: `~/.my-mac-ai/ical/memory.yaml`
- Schema: `references/calendar_rules.schema.json`
- Helper: `scripts/ical-memory`

Run `scripts/ical-memory` to print the global memory file.

## Schema

Memory files are YAML with a top-level `calendar_rules` array. Each rule has:

- `name`: short human-readable rule name
- `match`: natural-language match condition
- `behavior`: natural-language action guidance

Derive those fields from the conversation and save the rule when the user describes a habit.

The JSON Schema is for editor and validation tooling only. Do not read it on every calendar request; read it only when creating, editing, debugging, or validating memory files.

## Capturing a Rule

When the user describes a calendar habit, write it to the memory file immediately.

User:
```text
Usually book 30 minutes before the interview for prep and 30 minutes after for submitting review. If this is an interview type I have never done before, book 45 minutes before for prep instead.
```

Save to memory:
```yaml
# yaml-language-server: $schema=/Users/jlyu/play/mac/ical/.claude/skills/ical/references/calendar_rules.schema.json

calendar_rules:
  - name: Interview prep and submit review
    match: Events with "interview" in the title are interviews.
    behavior: >
      Book 30 minutes before the interview for prep and
      30 minutes after for submitting review.
      If this is an interview type never done before,
      book 45 minutes before for prep instead.
```

Confirm to the user: "Got it — I'll book time for prep and review around interviews from now on."

## Applying Rules

For every schedule or event-query response:

1. Run `scripts/ical-memory` to load rules.
2. Only apply rule for upcoming events, DO NOT evaluate past events.
2. Compare each returned event against every rule's `match` field.
3. When a rule matches, apply its `behavior` immediately — create the blocks, update the event, or take whatever action the behavior describes.
4. If rule is already satisfied skip it.
4. Report what was done inline with the event summary. Keep it brief.

**Example** — rule matched on `9:00AM-9:45AM B3 Java Backend Interview`:

```text
- 9:00AM-9:45AM  B3 Java Backend Interview
  → Booked 8:30AM-9:00AM Interview Prep · 9:45AM-10:15AM Submit interview review
```

If no memory file exists, skip this step and continue with the normal `ical` workflow.

If a memory file is invalid or a rule is ambiguous, note the issue briefly and skip that rule.
