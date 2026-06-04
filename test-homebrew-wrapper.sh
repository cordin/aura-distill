#!/bin/bash
# aura-distill Homebrew wrapper tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/homebrew/aura-distill-wrapper.sh"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
TEST_LIBEXEC="$TEST_ROOT/libexec"
REAL_LIBEXEC="$TEST_ROOT/real-libexec"
CALLS="$TEST_ROOT/calls.log"

PASS=0
FAIL=0

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
  PASS=$((PASS + 1))
  printf "  ✓ %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  ✗ %s\n" "$1"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if grep -Fq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

mkdir -p "$TEST_HOME" "$TEST_LIBEXEC"
printf "9.9.9\n" > "$TEST_LIBEXEC/VERSION"
cat > "$TEST_LIBEXEC/install.sh" <<'SH'
#!/bin/bash
{
  printf "AURA_DISTILL_REPO=%s\n" "${AURA_DISTILL_REPO:-}"
  printf "ARGS=%s\n" "$*"
} >> "$CALLS"
SH
chmod +x "$TEST_LIBEXEC/install.sh"

printf "\naura-distill Homebrew wrapper tests\n\n"

CALLS="$CALLS" HOME="$TEST_HOME" AURA_DISTILL_LIBEXEC="$TEST_LIBEXEC" \
  bash "$WRAPPER" install --target codex
assert_contains "$CALLS" "AURA_DISTILL_REPO=file://$TEST_LIBEXEC" \
  "install uses packaged Homebrew assets by default"
assert_contains "$CALLS" "ARGS=--target codex" \
  "install forwards Codex target"

: > "$CALLS"
CALLS="$CALLS" HOME="$TEST_HOME" AURA_DISTILL_LIBEXEC="$TEST_LIBEXEC" \
  bash "$WRAPPER" uninstall --target codex
assert_contains "$CALLS" "ARGS=--uninstall --target codex" \
  "Codex uninstall delegates to install.sh"

PROFILE="$TEST_HOME/.claude-personal"
mkdir -p "$PROFILE/commands" "$PROFILE/rules" "$PROFILE/distill"
touch "$PROFILE/commands/distill.md"
touch "$PROFILE/rules/distill.md"
touch "$PROFILE/distill/distill-process.md"
touch "$PROFILE/distill/distill-monitor.md"
touch "$PROFILE/distill/.version"
touch "$PROFILE/distill/SPINE.md"

CALLS="$CALLS" HOME="$TEST_HOME" AURA_DISTILL_LIBEXEC="$TEST_LIBEXEC" \
  bash "$WRAPPER" uninstall --profile personal >/dev/null

if [ ! -e "$PROFILE/commands/distill.md" ] &&
   [ ! -e "$PROFILE/rules/distill.md" ] &&
   [ ! -e "$PROFILE/distill/distill-process.md" ] &&
   [ ! -e "$PROFILE/distill/distill-monitor.md" ] &&
   [ ! -e "$PROFILE/distill/.version" ]; then
  pass "Claude uninstall removes integration files"
else
  fail "Claude uninstall removes integration files"
fi

if [ -e "$PROFILE/distill/SPINE.md" ]; then
  pass "Claude uninstall preserves knowledge files"
else
  fail "Claude uninstall preserves knowledge files"
fi

VERSION_OUTPUT="$(HOME="$TEST_HOME" AURA_DISTILL_LIBEXEC="$TEST_LIBEXEC" bash "$WRAPPER" version)"
if [ "$VERSION_OUTPUT" = "9.9.9" ]; then
  pass "version reads packaged VERSION"
else
  fail "version reads packaged VERSION"
fi

mkdir -p "$REAL_LIBEXEC/rules" "$REAL_LIBEXEC/codex"
cp "$SCRIPT_DIR/install.sh" \
   "$SCRIPT_DIR/VERSION" \
   "$SCRIPT_DIR/LICENSE" \
   "$SCRIPT_DIR/distill.md" \
   "$SCRIPT_DIR/distill-process.md" \
   "$SCRIPT_DIR/distill-monitor.md" \
   "$SCRIPT_DIR/banner.txt" \
   "$REAL_LIBEXEC/"
cp "$SCRIPT_DIR/rules/distill.md" "$REAL_LIBEXEC/rules/distill.md"
cp -R "$SCRIPT_DIR/codex/distill-adapter.md" "$REAL_LIBEXEC/codex/"
cp -R "$SCRIPT_DIR/codex/skills" "$REAL_LIBEXEC/codex/"

REAL_HOME="$TEST_ROOT/real-home"
REAL_CODEX_HOME="$REAL_HOME/.codex"
mkdir -p "$REAL_HOME"

HOME="$REAL_HOME" CODEX_HOME="$REAL_CODEX_HOME" AURA_DISTILL_LIBEXEC="$REAL_LIBEXEC" \
  bash "$WRAPPER" install --target codex >/dev/null

if [ -f "$REAL_HOME/.agents/skills/distill/SKILL.md" ] &&
   [ -f "$REAL_CODEX_HOME/distill/distill-process.md" ] &&
   [ -f "$REAL_CODEX_HOME/distill/distill-adapter.md" ] &&
   [ -f "$REAL_CODEX_HOME/distill/distill-monitor.md" ]; then
  pass "wrapper installs Codex from packaged Homebrew assets"
else
  fail "wrapper installs Codex from packaged Homebrew assets"
fi

if [ "$FAIL" -eq 0 ]; then
  printf "\nAll %d tests passed\n" "$PASS"
  exit 0
fi

printf "\n%d passed, %d failed\n" "$PASS" "$FAIL"
exit 1
