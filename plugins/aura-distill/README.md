# aura-distill Codex Plugin

This package exposes aura-distill as a native Codex plugin. It bundles the
`$distill` skill so Codex can consolidate session corrections, failures,
preferences, surprises, and decisions into durable principle knowledge.

Install from a local checkout with:

```bash
codex plugin marketplace add .
codex plugin add aura-distill@aura-distill
```

The plugin package is intentionally narrow:

- It provides the native `$distill` skill.
- It bundles the shared process, Codex adapter, and monitor references needed
  by the skill.
- It does not provide hooks; Codex does not currently expose Claude-style hook
  events.

The Bash, PowerShell, and Homebrew installers remain supported. They are still
the full setup path for creating `$CODEX_HOME/distill/`, installing rendered
shared process files, and adding the managed `AGENTS.md` retrieval block.
