# Retrospective Distillation Process For Codex

Consolidate the supplied signal harvest into durable first-principles knowledge
under `{DISTILL_DIR}/`. Never write outside that directory.

## Integrity Principles

1. Never encode comfort as truth.
2. Never flatten standards to reduce friction.
3. Never confuse preference with principle.
4. Treat frustration as diagnostic, not directive.
5. Optimize for the user's long-term capability.

## 0. Acquire The Lock And Discover Structure

Write `running <UTC timestamp>` to `{DISTILL_DIR}/.status`. Read
`{DISTILL_DIR}/SPINE.md`, then inspect the active tier directories:

- `craft/`: durable practice standards
- `ops/`: workflows and operational procedures
- `projects/`: project-specific context
- `profile/`: evidence-based user model
- `feedback/`: collaboration preferences
- `archive/`: compressed superseded history

Read global and project `AGENTS.md` files only for conflict detection. Read
`$CODEX_HOME/memories/` only when useful for conflict detection. Do not edit
either source. If ambient Codex Memories conflict with aura-distill knowledge,
preserve and apply the curated aura-distill version and report the conflict.

Validate SPINE pointers before writing. Report missing targets and backups
instead of silently creating a fresh knowledge base over displaced knowledge.

## 1. Identify And Trace Signals

For each supplied signal:

1. State what happened.
2. Trace why it happened until the learning is reusable beyond the immediate
   incident.
3. Classify its origin as `evidence`, `directive`, `convention`, or
   `constraint`.
4. Distinguish an observed fact, a user preference, and a durable principle.

Record confidence as `experimental`, `provisional`, `validated`, or `hardened`.
Use `[CONTEXT]`, `[UPDATED]`, `[PROVISIONAL]`, `[IMPORTANT]`,
`[NON-NEGOTIABLE]`, `[DIRECTIVE]`, `[CORRECTED]`, and `[DEPRECATED]` markers
where they materially change future behavior.

## 2. Encode At The Right Layer

Update an existing focused Tier 2 file when possible. Before creating a new
top-level knowledge file, ask the user for confirmation. Keep Tier 2 files to
one topic and no more than 60 lines. Each actionable entry should explain why
it exists and include confidence metadata when available.

Maintain `SPINE.md` as an index only:

```markdown
- [Title](relative/path.md) - when to read this
```

Keep it under 80 lines. Every active Tier 2 file must have a SPINE pointer and
every SPINE pointer must resolve.

## 3. Verify And Compact

For each encoded learning, verify that it is actionable, findable, justified,
general enough to survive the immediate project, and reachable when needed.
Run an anti-sycophancy pass: encode evidence honestly even when a softer
summary would feel easier.

If SPINE exceeds 60 lines or an active Tier 2 file exceeds 45 lines, compact
it. Move superseded detail to `archive/`; never discard history.

Write `idle <UTC timestamp>` to `{DISTILL_DIR}/.status` after successful
completion.

## 4. Report

Return:

- signals processed and principles extracted
- files updated
- user-model changes
- tier health
- flagged tensions and conflicts with ambient Codex Memories
- bridge suggestions for important knowledge that needs a pointer in a
  user-managed workflow file
- open questions
