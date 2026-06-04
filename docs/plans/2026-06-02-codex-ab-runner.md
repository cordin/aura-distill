# Codex Retrieval A/B Runner

## Summary

Add a Codex-native A/B runner for the six existing retrieval scenarios. Keep the
Claude Code research runners unchanged.

The runner must exercise actual Codex instruction discovery through an isolated
`$CODEX_HOME/AGENTS.md`, the installed aura-distill monitor, `SPINE.md`, and
scenario Tier 2 files. It must never read or write the user's real Codex profile.

## Public Interface

```bash
CODEX_API_KEY="..." \
CODEX_TEST_MODEL="..." \
  ./tests/scenarios/methodology/run-codex-ab.sh

CODEX_API_KEY="..." \
CODEX_TEST_MODEL="..." \
  ./tests/scenarios/methodology/run-codex-ab.sh 01-repeated-correction

CODEX_AB_AUTH_FILE="$HOME/.codex/auth.json" \
CODEX_TEST_MODEL="..." \
CODEX_AB_REPEATS=1 \
  ./tests/scenarios/methodology/run-codex-ab.sh 01-repeated-correction
```

Each scenario runs three paired repetitions by default, alternating condition
order:

```text
WITHOUT, WITH
WITH, WITHOUT
WITHOUT, WITH
```

## Implementation

1. Create disposable `HOME`, `CODEX_HOME`, and Git workspace directories.
2. Install the local Codex integration into the disposable profile.
3. Copy each retrieval scenario's knowledge tree into the isolated distill
   store.
4. Run `codex exec --ephemeral` with the managed aura-distill `AGENTS.md` block
   removed for the `WITHOUT` condition and present for the `WITH` condition.
5. Use read-only sandboxing, ignore user config and execpolicy rules, and pass
   `CODEX_API_KEY` only to the individual `codex exec` invocation. For local
   smoke tests, accept an explicit auth cache path and copy it into the
   disposable profiles with restrictive permissions.
6. Fail closed when required distill retrieval cannot read Tier 2 files. Allow
   an explicit child-sandbox bypass only for trusted local fixtures when nested
   sandboxing is unavailable.
7. Save raw output, standard error, the rubric, and run metadata under a
   timestamped Codex results directory.

## Test Plan

- Add a fake-Codex integration harness that runs entirely in temporary
  directories.
- Verify the default three repetitions produce six model calls for one
  scenario in alternating order.
- Verify every invocation uses an isolated `HOME`, isolated `CODEX_HOME`,
  ephemeral mode, read-only sandboxing, ignored user config, ignored rules,
  and a clean subprocess environment policy.
- Verify the `WITHOUT` profile omits the managed distill block.
- Verify the `WITH` profile includes the managed block and copied scenario
  knowledge.
- Verify the runner requests a clean subprocess environment policy.
- Verify the optional local auth cache path is copied only into disposable
  profiles.
- Verify the explicit controlled child-sandbox bypass.

## Validation Notes

- The default read-only child sandbox fails closed in this environment because
  nested Codex shell reads cannot access the fixture files.
- The valid local run used `CODEX_AB_BYPASS_SANDBOX=1` with disposable
  `HOME`, `CODEX_HOME`, workspace, and auth-cache copies.
- Full Codex retrieval A/B validation completed on 2026-06-04:
  six retrieval scenarios, three paired repetitions, 36 responses, all
  informed runs verified Tier 2 reads, no credential matches in result files.
- Run the existing Codex installer suite and Claude installer subset.
