# Codex Adapter For Retrospective Distillation

Read this file before the shared `distill-process.md`. The shared process is
the source of truth for distillation behavior. Apply these Codex-specific
overrides wherever the shared process uses Claude Code terminology.

## Runtime Surface

| Shared process reference | Codex behavior |
|---|---|
| `/distill` | Invoke the native `$distill` skill |
| Claude Code | Codex |
| `~/.claude/CLAUDE.md` and project `CLAUDE.md` | `$CODEX_HOME/AGENTS.md` and active project `AGENTS.md` files |
| `rules/distill.md` | Installed as `{DISTILL_DIR}/distill-monitor.md` with Codex substitutions |
| Claude `memory/` files | Codex Memories under `$CODEX_HOME/memories/` |

## Knowledge Ownership

Codex built-in Memories remain enabled or disabled according to the user's
existing configuration. Read them only when useful for conflict detection.
Never modify, disable, or migrate them automatically.

When ambient Codex Memories and aura-distill overlap, preserve and apply the
curated aura-distill version. Report material conflicts.

## Preference Sync

When the shared process syncs always-on preferences, update the
`## Always-On User Preferences` section in
`{DISTILL_DIR}/distill-monitor.md`. Preserve the rest of that file unchanged.

The installed `$CODEX_HOME/AGENTS.md` block points Codex to the monitor. Do not
write distilled preferences into user-managed `AGENTS.md` files.

## Bridge Suggestions

For Codex, suggest pointers in user-managed `AGENTS.md` files when important
knowledge would otherwise be unreachable. Never edit those files during
distillation.

## Updates

The Codex installer owns installed assets. If an update is accepted, refresh
through the installer so path placeholders are resolved consistently:

```bash
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/install.sh |
  bash -s -- --target codex
```
