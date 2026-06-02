---
name: distill
description: Consolidate this Codex conversation's corrections, failures, preferences, surprises, and decision origins into durable first-principles knowledge. Use when the user asks to distill, remember learnings, save takeaways, or consolidate the session.
---

<!-- aura-distill:codex-skill -->

# Retrospective Distillation

Run distillation through a foreground subagent. Do not perform the full
distillation process in the main conversation context.

## 1. Pre-flight

1. Read `{DISTILL_DIR}/.status` if it exists.
2. If it starts with `running` and is less than five minutes old, ask whether
   to wait or stop.
3. If it starts with `running step:`, tell the user a previous run was
   interrupted and ask whether to resume or start fresh.
4. Read `{DISTILL_DIR}/SPINE.md`.

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

Read and follow the complete process:
{DISTILL_DIR}/distill-process.md

Session signal harvest:
[INSERT FULL HARVEST]

You must write only under {DISTILL_DIR}/. Report any denied write immediately.
Return: signals processed, learnings encoded with paths, user-model updates,
tier health, flagged tensions, bridge suggestions, and open questions.
```

Wait for the subagent to finish. If Codex cannot spawn a subagent in the
current surface, report that limitation and do not silently run the full
pipeline in the main context.

## 4. Load Results

Read `{DISTILL_DIR}/SPINE.md`, then relay the report concisely. Surface the
encoded principles, file paths, flagged tensions, bridge suggestions, and open
questions.
