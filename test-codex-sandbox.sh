#!/bin/bash
# aura-distill Codex installer integration tests
# Uses disposable HOME and CODEX_HOME directories only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_HOME=$(mktemp -d)
TEST_CODEX_HOME="$TEST_HOME/.codex"
TEST_SKILL="$TEST_HOME/.agents/skills/distill/SKILL.md"
LOCAL_REPO="file://$SCRIPT_DIR"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
  rm -rf "$TEST_HOME"
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

assert_file() {
  if [ -f "$1" ]; then pass "$2"; else fail "$2"; fi
}

assert_dir() {
  if [ -d "$1" ]; then pass "$2"; else fail "$2"; fi
}

install_codex() {
  HOME="$TEST_HOME" \
  CODEX_HOME="$TEST_CODEX_HOME" \
  AURA_DISTILL_REPO="$LOCAL_REPO" \
    bash "$SCRIPT_DIR/install.sh" --target codex >/dev/null
}

uninstall_codex() {
  HOME="$TEST_HOME" \
  CODEX_HOME="$TEST_CODEX_HOME" \
  AURA_DISTILL_REPO="$LOCAL_REPO" \
    bash "$SCRIPT_DIR/install.sh" --uninstall --target codex >/dev/null
}

printf "\naura-distill Codex installer tests\n\n"

mkdir -p "$TEST_CODEX_HOME/memories"
printf 'model = "existing-model"\n' > "$TEST_CODEX_HOME/config.toml"
printf '# Existing global guidance\n' > "$TEST_CODEX_HOME/AGENTS.md"
printf 'ambient memory stays untouched\n' > "$TEST_CODEX_HOME/memories/existing.md"
cp "$TEST_CODEX_HOME/config.toml" "$TEST_HOME/config.before"
cp "$TEST_CODEX_HOME/memories/existing.md" "$TEST_HOME/memory.before"

install_codex

assert_file "$TEST_SKILL" "native distill skill installed"
assert_file "$TEST_CODEX_HOME/distill/distill-process.md" "Codex process installed"
assert_file "$TEST_CODEX_HOME/distill/distill-monitor.md" "Codex monitor installed"
assert_file "$TEST_CODEX_HOME/distill/SPINE.md" "SPINE created"
assert_file "$TEST_CODEX_HOME/distill/.version" "version file created"

if grep -q "$TEST_CODEX_HOME/distill/SPINE.md" "$TEST_CODEX_HOME/AGENTS.md" &&
   grep -q "$TEST_CODEX_HOME/distill/distill-process.md" "$TEST_SKILL"; then
  pass "installer resolves Codex distill path placeholders"
else
  fail "installer resolves Codex distill path placeholders"
fi

for dir in craft ops profile projects feedback archive; do
  assert_dir "$TEST_CODEX_HOME/distill/$dir" "tier directory $dir created"
done

if grep -q '<!-- aura-distill:codex:start -->' "$TEST_CODEX_HOME/AGENTS.md" &&
   grep -q '# Existing global guidance' "$TEST_CODEX_HOME/AGENTS.md"; then
  pass "managed AGENTS block appended without replacing existing guidance"
else
  fail "managed AGENTS block appended without replacing existing guidance"
fi

if cmp -s "$TEST_CODEX_HOME/config.toml" "$TEST_HOME/config.before"; then
  pass "existing Codex config preserved"
else
  fail "existing Codex config preserved"
fi

if cmp -s "$TEST_CODEX_HOME/memories/existing.md" "$TEST_HOME/memory.before"; then
  pass "existing Codex Memories preserved"
else
  fail "existing Codex Memories preserved"
fi

printf '%s\n' '- [Custom](craft/custom.md) - custom knowledge' >> "$TEST_CODEX_HOME/distill/SPINE.md"
install_codex

if [ "$(grep -c '<!-- aura-distill:codex:start -->' "$TEST_CODEX_HOME/AGENTS.md")" -eq 1 ]; then
  pass "reinstall avoids duplicate AGENTS block"
else
  fail "reinstall avoids duplicate AGENTS block"
fi

if grep -q 'craft/custom.md' "$TEST_CODEX_HOME/distill/SPINE.md"; then
  pass "reinstall preserves SPINE knowledge"
else
  fail "reinstall preserves SPINE knowledge"
fi

printf '# Durable principle\n' > "$TEST_CODEX_HOME/distill/craft/custom.md"
uninstall_codex

if [ ! -f "$TEST_SKILL" ] &&
   [ ! -f "$TEST_CODEX_HOME/distill/distill-process.md" ] &&
   [ ! -f "$TEST_CODEX_HOME/distill/distill-monitor.md" ] &&
   [ ! -f "$TEST_CODEX_HOME/distill/.version" ]; then
  pass "uninstall removes integration assets"
else
  fail "uninstall removes integration assets"
fi

if [ -f "$TEST_CODEX_HOME/distill/SPINE.md" ] &&
   [ -f "$TEST_CODEX_HOME/distill/craft/custom.md" ]; then
  pass "uninstall preserves distilled knowledge"
else
  fail "uninstall preserves distilled knowledge"
fi

if ! grep -q '<!-- aura-distill:codex:start -->' "$TEST_CODEX_HOME/AGENTS.md" &&
   grep -q '# Existing global guidance' "$TEST_CODEX_HOME/AGENTS.md"; then
  pass "uninstall removes managed AGENTS block only"
else
  fail "uninstall removes managed AGENTS block only"
fi

mkdir -p "$(dirname "$TEST_SKILL")"
printf '# User-owned distill skill\n' > "$TEST_SKILL"
uninstall_codex
if grep -q '# User-owned distill skill' "$TEST_SKILL"; then
  pass "uninstall preserves unrelated user-owned skill"
else
  fail "uninstall preserves unrelated user-owned skill"
fi

if install_codex 2>/dev/null; then
  fail "install refuses to overwrite unrelated user-owned skill"
elif grep -q '# User-owned distill skill' "$TEST_SKILL"; then
  pass "install refuses to overwrite unrelated user-owned skill"
else
  fail "install refuses to overwrite unrelated user-owned skill"
fi

printf "\nResults: %d passed, %d failed, %d total\n\n" \
  "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_RUN"

[ "$TESTS_FAILED" -eq 0 ]
