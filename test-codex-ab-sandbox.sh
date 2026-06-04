#!/bin/bash
# aura-distill Codex A/B runner integration tests
# Uses a fake Codex executable and disposable directories only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_ROOT=$(mktemp -d)
FAKE_CODEX="$TEST_ROOT/fake-codex"
FAKE_LOG="$TEST_ROOT/fake-codex.log"
RESULTS_DIR="$TEST_ROOT/results"
RUNNER="$SCRIPT_DIR/tests/scenarios/methodology/run-codex-ab.sh"
FAKE_API_KEY="codex-ab-test-key"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  PASS %s\n" "$1"
}

fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  FAIL %s\n" "$1"
}

cat > "$FAKE_CODEX" <<'EOF'
#!/bin/bash
set -euo pipefail

contains_arg() {
  local expected="$1"
  shift
  local arg

  for arg in "$@"; do
    [ "$arg" = "$expected" ] && return 0
  done

  return 1
}

condition="WITHOUT"
if grep -q '<!-- aura-distill:codex:start -->' "$CODEX_HOME/AGENTS.md"; then
  condition="WITH"
fi

[ "$1" = "exec" ]
contains_arg "--ephemeral" "$@"
contains_arg "--ignore-user-config" "$@"
contains_arg "--ignore-rules" "$@"
if contains_arg "--dangerously-bypass-approvals-and-sandbox" "$@"; then
  :
else
  contains_arg "read-only" "$@"
fi
contains_arg 'shell_environment_policy.inherit="none"' "$@"
contains_arg "codex-test-model" "$@"

[ "$HOME" != "$CODEX_AB_FORBIDDEN_HOME" ]
[ -f "$CODEX_HOME/distill/SPINE.md" ]
[ -s "$CODEX_HOME/distill/SPINE.md" ]
if [ -n "${CODEX_API_KEY:-}" ]; then
  [ "$CODEX_API_KEY" = "codex-ab-test-key" ]
else
  grep -q 'fake-auth-cache' "$CODEX_HOME/auth.json"
fi

if [ "$condition" = "WITHOUT" ]; then
  ! grep -q '<!-- aura-distill:codex:start -->' "$CODEX_HOME/AGENTS.md"
else
  grep -q 'distill/SPINE.md' "$CODEX_HOME/AGENTS.md"
fi

printf '%s|%s|%s\n' "$condition" "$HOME" "$CODEX_HOME" >> "$CODEX_AB_FAKE_LOG"
printf 'fake response for %s\n' "$condition"
EOF
chmod +x "$FAKE_CODEX"
: > "$FAKE_LOG"

printf "\naura-distill Codex A/B runner tests\n\n"

if CODEX_API_KEY="$FAKE_API_KEY" \
   CODEX_TEST_MODEL="codex-test-model" \
   CODEX_BIN="$FAKE_CODEX" \
   CODEX_AB_FAKE_LOG="$FAKE_LOG" \
   CODEX_AB_FORBIDDEN_HOME="$HOME" \
   CODEX_AB_RESULTS_DIR="$RESULTS_DIR" \
     "$RUNNER" 01-repeated-correction >/dev/null; then
  pass "runner completes isolated fake-Codex scenario"
else
  find "$RESULTS_DIR" -name '*.stderr.txt' -exec cat {} \; 2>/dev/null || true
  fail "runner completes isolated fake-Codex scenario"
fi

if [ "$(wc -l < "$FAKE_LOG")" -eq 6 ]; then
  pass "default runner performs three paired repetitions"
else
  fail "default runner performs three paired repetitions"
fi

if cut -d'|' -f1 "$FAKE_LOG" | paste -sd ' ' - |
   grep -qx 'WITHOUT WITH WITH WITHOUT WITHOUT WITH'; then
  pass "runner alternates A/B order"
else
  fail "runner alternates A/B order"
fi

if [ "$(find "$RESULTS_DIR" -name '01-repeated-correction_run-*_WITHOUT.txt' | wc -l)" -eq 3 ] &&
   [ "$(find "$RESULTS_DIR" -name '01-repeated-correction_run-*_WITH.txt' | wc -l)" -eq 3 ]; then
  pass "runner saves raw output for each condition"
else
  fail "runner saves raw output for each condition"
fi

if [ -f "$RESULTS_DIR/01-repeated-correction_expected.md" ] &&
   [ -f "$RESULTS_DIR/metadata.txt" ]; then
  pass "runner saves rubric and metadata"
else
  fail "runner saves rubric and metadata"
fi

if ! grep -R "$FAKE_API_KEY" "$RESULTS_DIR" "$FAKE_LOG" >/dev/null 2>&1; then
  pass "runner does not write API key into results or logs"
else
  fail "runner does not write API key into results or logs"
fi

if awk -F'|' -v forbidden="$HOME" '
    $2 == forbidden { exit 1 }
    $3 !~ /aura-distill-codex-ab/ { exit 1 }
  ' "$FAKE_LOG"; then
  pass "runner uses disposable HOME and CODEX_HOME directories"
else
  fail "runner uses disposable HOME and CODEX_HOME directories"
fi

if CODEX_TEST_MODEL="codex-test-model" \
   CODEX_BIN="$FAKE_CODEX" \
   CODEX_AB_FAKE_LOG="$FAKE_LOG" \
   CODEX_AB_FORBIDDEN_HOME="$HOME" \
   CODEX_AB_RESULTS_DIR="$RESULTS_DIR/missing-key" \
     "$RUNNER" 01-repeated-correction >/dev/null 2>&1; then
  fail "runner requires scoped CODEX_API_KEY"
else
  pass "runner requires scoped authentication"
fi

printf 'fake-auth-cache\n' > "$TEST_ROOT/auth.json"
if CODEX_AB_AUTH_FILE="$TEST_ROOT/auth.json" \
   CODEX_TEST_MODEL="codex-test-model" \
   CODEX_BIN="$FAKE_CODEX" \
   CODEX_AB_FAKE_LOG="$FAKE_LOG" \
   CODEX_AB_FORBIDDEN_HOME="$HOME" \
   CODEX_AB_REPEATS=1 \
   CODEX_AB_RESULTS_DIR="$RESULTS_DIR/auth-file" \
     "$RUNNER" 01-repeated-correction >/dev/null; then
  pass "runner supports disposable local auth cache copies"
else
  fail "runner supports disposable local auth cache copies"
fi

: > "$FAKE_LOG"
if CODEX_API_KEY="$FAKE_API_KEY" \
   CODEX_TEST_MODEL="codex-test-model" \
   CODEX_BIN="$FAKE_CODEX" \
   CODEX_AB_FAKE_LOG="$FAKE_LOG" \
   CODEX_AB_FORBIDDEN_HOME="$HOME" \
   CODEX_AB_REPEATS=1 \
   CODEX_AB_RESULTS_DIR="$RESULTS_DIR/all-scenarios" \
     "$RUNNER" >/dev/null &&
   [ "$(wc -l < "$FAKE_LOG")" -eq 12 ] &&
   [ "$(find "$RESULTS_DIR/all-scenarios" -name '*_expected.md' | wc -l)" -eq 6 ]; then
  pass "runner enumerates all six retrieval scenarios"
else
  fail "runner enumerates all six retrieval scenarios"
fi

if CODEX_API_KEY="$FAKE_API_KEY" \
   CODEX_TEST_MODEL="codex-test-model" \
   CODEX_BIN="$FAKE_CODEX" \
   CODEX_AB_FAKE_LOG="$FAKE_LOG" \
   CODEX_AB_FORBIDDEN_HOME="$HOME" \
   CODEX_AB_BYPASS_SANDBOX=1 \
   CODEX_AB_REPEATS=1 \
   CODEX_AB_RESULTS_DIR="$RESULTS_DIR/bypassed-sandbox" \
     "$RUNNER" 01-repeated-correction >/dev/null; then
  pass "runner supports explicit controlled sandbox bypass"
else
  fail "runner supports explicit controlled sandbox bypass"
fi

if CODEX_API_KEY="$FAKE_API_KEY" \
   CODEX_TEST_MODEL="codex-test-model" \
   CODEX_BIN="$FAKE_CODEX" \
   CODEX_AB_FAKE_LOG="$FAKE_LOG" \
   CODEX_AB_FORBIDDEN_HOME="$HOME" \
   CODEX_AB_REPEATS=0 \
   CODEX_AB_RESULTS_DIR="$RESULTS_DIR/invalid-repeats" \
     "$RUNNER" 01-repeated-correction >/dev/null 2>&1; then
  fail "runner rejects invalid repeat count"
else
  pass "runner rejects invalid repeat count"
fi

if CODEX_API_KEY="$FAKE_API_KEY" \
   CODEX_TEST_MODEL="codex-test-model" \
   CODEX_BIN="$FAKE_CODEX" \
   CODEX_AB_FAKE_LOG="$FAKE_LOG" \
   CODEX_AB_FORBIDDEN_HOME="$HOME" \
   CODEX_AB_BYPASS_SANDBOX=unexpected \
   CODEX_AB_RESULTS_DIR="$RESULTS_DIR/invalid-sandbox" \
     "$RUNNER" 01-repeated-correction >/dev/null 2>&1; then
  fail "runner rejects invalid sandbox bypass value"
else
  pass "runner rejects invalid sandbox bypass value"
fi

printf "\nResults: %d passed, %d failed, %d total\n\n" \
  "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_RUN"

[ "$TESTS_FAILED" -eq 0 ]
