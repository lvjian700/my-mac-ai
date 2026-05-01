# Agent Guide (kanban)

## Kanban

| Folder | Purpose |
|--------|---------|
| `todo/` | Planned features - one file per feature |
| `doing/` | Work in progress |
| `done/` | Completed work, filed with version prefix |

**File naming:**

- `todo/{feature_brief}.md` - created when a feature is planned
- `doing/{feature_brief}.md` - move from `todo/` when work starts
- `done/{version}-{feature_brief}.md` - move from `doing/` when done

## Versioning

| Bump | Pattern | When |
|------|---------|------|
| Major | `1.x.x` | New feature |
| Minor | `x.1.x` | Smaller update or sub-feature |
| Patch | `x.x.1` | Bug fix or task completion - auto-increment per patch |

## Workflow

1. Start a new planning, write the file in `todo/` folder, auto naming the file `{plan title}.md`.
2. Move the plan to `doing/` when starting work, keep context in the same plan file, and don't auto mark it as done.
3. Move to `done/` when the user prompts that the feature is done, auto increase patch version, e.g. `0.0.1 -> 0.0.2`. Do not move to `done/` if the user marks the plan as not a feature.

## Auto Increase Patch Version

1. Check files with `ls`.
2. Find the latest version from the file list.
3. Use the latest version as the base and auto increase patch version as the new version.
