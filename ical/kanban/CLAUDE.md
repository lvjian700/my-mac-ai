# CLAUDE.md (kanban)

## Kanban Workflow

| Folder | Purpose |
|--------|---------|
| `todo/` | Planned features — one file per feature |
| `doing/` | Work in progress |
| `done/` | Completed work, filed with version prefix |

**File naming:**
- `todo/{feature_brief}.md` — created when a feature is planned
- `doing/{feature_brief}.md` — move from `todo/` when work starts
- `done/{version}-{feature_brief}.md` — move from `doing/` when done, prepend resolved version

## Versioning

| Bump | Pattern | When |
|------|---------|------|
| Major | `1.x.x` | New feature |
| Minor | `x.1.x` | Smaller update or sub-feature |
| Patch | `x.x.1` | Bug fix or task completion — auto-increment per minor |
