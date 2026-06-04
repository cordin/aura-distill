# Research Scenarios

Organized by capability being tested:

```
scenarios/
├── retrieval/          Does it USE knowledge correctly?
│   ├── 01-06           Original A/B scenarios (anti-sycophancy, etc.)
│   ├── confidence/     Assertiveness scaling with confidence metadata
│   ├── memory-rot/     Does flat memory degrade? (found retrieval bug)
│   └── tool-reliability/ Past failures → proactive prevention (0/5 vs 5/5)
│
├── cognitive/          Does it PROTECT the human?
│   ├── decision-fatigue/  Metacognitive warning under heavy context
│   ├── anchoring-bias/    Structured pushback vs hedging
│   ├── loss-aversion/     Reframing user's own logic
│   ├── authority-bias/    Transparent compliance with origin tracking
│   └── philosophical/     Engineering vs philosophy hybrid
│
├── distillation/       Does it LEARN correctly? (NEW)
│   └── (signal extraction, origin classification, full-loop)
│
└── methodology/        Shared infrastructure
    ├── FICTIONAL-COMPANY.md    Helios Financial (fictional test context)
    ├── run-persona-test.sh     Unified persona test runner
    ├── run-ab.sh               Original A/B framework
    ├── persona-sofia/          Lead engineer persona + knowledge
    ├── persona-marcus/         PM persona + knowledge
    └── sofia-*/                Original Sofia scenario prompts
```

## Running tests

```bash
# Persona-based (uses the configured test profile for auth)
./methodology/run-persona-test.sh sofia loss-aversion
./methodology/run-persona-test.sh marcus anchoring-bias

# Standalone (each scenario has its own runner)
./retrieval/tool-reliability/run-tool-reliability-test.sh
./cognitive/anchoring-bias/run-anchoring-test.sh
```

### Codex retrieval A/B tests

The Codex runner uses disposable `HOME`, `CODEX_HOME`, and Git workspace
directories. It does not read or write your normal Codex profile. Pass an API
key only to the runner invocation:

```bash
# Run the six original retrieval scenarios, three paired repetitions each
CODEX_API_KEY="..." CODEX_TEST_MODEL="..." \
  ./methodology/run-codex-ab.sh

# Run one scenario
CODEX_API_KEY="..." CODEX_TEST_MODEL="..." \
  ./methodology/run-codex-ab.sh 01-repeated-correction
```

For a local smoke test using an existing file-backed ChatGPT login, explicitly
point the runner at the cache. It copies the file into disposable profiles and
removes those copies afterward:

```bash
CODEX_AB_AUTH_FILE="$HOME/.codex/auth.json" CODEX_TEST_MODEL="..." \
  CODEX_AB_REPEATS=1 ./methodology/run-codex-ab.sh 01-repeated-correction
```

The runner uses Codex's read-only child sandbox by default and fails closed if
Tier 2 retrieval cannot run. In a controlled local environment where nested
sandboxing is unavailable, you can explicitly bypass the child sandbox. The
workspace and Codex profiles remain disposable, but the Codex process itself
can access the host, so use only the repository's trusted fixtures:

```bash
CODEX_AB_AUTH_FILE="$HOME/.codex/auth.json" CODEX_TEST_MODEL="..." \
  CODEX_AB_BYPASS_SANDBOX=1 ./methodology/run-codex-ab.sh
```

Each scenario alternates `WITHOUT, WITH`, then `WITH, WITHOUT`, then
`WITHOUT, WITH`. Raw responses, stderr, run metadata, and the scenario rubric
are saved under `methodology/results/codex/`.

## Rules

1. **No real company names** in any test output. Use Helios Financial.
2. **Verify cleanliness** before committing: `grep -r "N26\|Magneton" .`
3. **All results reproducible** via the test scripts.
