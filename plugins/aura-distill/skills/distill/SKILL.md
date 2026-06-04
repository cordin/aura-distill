---
name: distill
description: Consolidate this Codex conversation's corrections, failures, preferences, surprises, and decision origins into durable first-principles knowledge. Use when the user asks to distill, remember learnings, save takeaways, or consolidate the session.
---

<!-- aura-distill:codex-skill -->

# Retrospective Distillation

Run distillation through a foreground subagent. Do not perform the full
distillation process in the main conversation context. Invoke this skill as
`$distill`.

This plugin package is self-contained. It uses `$CODEX_HOME/distill` as the
knowledge directory, defaulting to `~/.codex/distill` when `CODEX_HOME` is not
set. It includes bundled references under this skill's `references/` directory:

- `references/distill-adapter.md`
- `references/distill-process.md`
- `references/distill-monitor.md`

If an installer-managed `$CODEX_HOME/distill/distill-adapter.md` and
`distill-process.md` already exist, prefer those installed files. Otherwise,
read the bundled references directly.

## 1. Pre-flight

1. Resolve the distill directory:
   - If `CODEX_HOME` is set, use `$CODEX_HOME/distill`.
   - Otherwise use `~/.codex/distill`.
2. Ensure the distill directory and tier folders exist:
   `craft`, `ops`, `profile`, `projects`, `feedback`, and `archive`.
3. If `SPINE.md` does not exist, create it with:

   ```markdown
   # Distill Knowledge Index

   <!-- This file is managed by aura-distill. Max 80 lines. -->
   <!-- Each entry: - [Title](path.md) - when to read this -->
   ```

4. Read `.status` if it exists.
5. If it starts with `running` and is less than five minutes old, ask whether
   to wait or stop.
6. If it starts with `running step:`, tell the user a previous run was
   interrupted and ask whether to resume or start fresh.
7. Read `SPINE.md`.

## 2. Harvest Signals

Scan the full conversation and prepare a structured signal harvest:

- failures, friction, retries, and surprises
- user corrections and non-obvious teachings
- preferences and collaboration patterns
- decisions and their origins: `evidence`, `directive`, `convention`, or
  `constraint`
- session goal, domains, complexity, and outcome

The subagent cannot see the original conversation. Include enough detail for it
to reason independently.

## 3. Spawn The Distillation Agent

Spawn a foreground `worker` subagent with this prompt:

```text
You are a Distillation Agent. Consolidate the supplied session signal harvest
into durable knowledge.

Resolve the active distill directory from CODEX_HOME, defaulting to
~/.codex/distill. Write only under that directory.

Read the Codex adapter first, then follow the shared complete process. Prefer
installed files under the active distill directory if present:
- distill-adapter.md
- distill-process.md

If those installed files are absent, use the bundled plugin references:
- references/distill-adapter.md
- references/distill-process.md

When the shared process refers to {DISTILL_DIR}, substitute the active distill
directory you resolved above.

Session signal harvest:
[INSERT FULL HARVEST]

Return: signals processed, learnings encoded with paths, user-model updates,
tier health, flagged tensions, bridge suggestions, and open questions.
```

Wait for the subagent to finish. If Codex cannot spawn a subagent in the
current surface, report that limitation and do not silently run the full
pipeline in the main context.

## 4. Load Results

Read `SPINE.md` from the active distill directory, then relay the report
concisely. Surface the encoded principles, file paths, flagged tensions, bridge
suggestions, and open questions.
