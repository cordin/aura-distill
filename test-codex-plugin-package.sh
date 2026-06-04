#!/bin/bash
# aura-distill Codex plugin package tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/plugins/aura-distill"
MARKETPLACE="$SCRIPT_DIR/.agents/plugins/marketplace.json"
VALIDATOR="/home/cordin/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf "  PASS %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  FAIL %s\n" "$1"
}

assert_file() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Fq "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

printf "\naura-distill Codex plugin package tests\n\n"

assert_file "$PLUGIN_DIR/.codex-plugin/plugin.json" "plugin manifest exists"
assert_file "$MARKETPLACE" "repo marketplace exists"
assert_file "$PLUGIN_DIR/skills/distill/SKILL.md" "distill skill exists"
assert_file "$PLUGIN_DIR/skills/distill/references/distill-adapter.md" "bundled Codex adapter exists"
assert_file "$PLUGIN_DIR/skills/distill/references/distill-process.md" "bundled process reference exists"
assert_file "$PLUGIN_DIR/skills/distill/references/distill-monitor.md" "bundled monitor reference exists"
assert_contains "$PLUGIN_DIR/.codex-plugin/plugin.json" '"skills": "./skills/"' \
  "plugin manifest exposes skills directory"
assert_contains "$PLUGIN_DIR/skills/distill/SKILL.md" '<!-- aura-distill:codex-skill -->' \
  "plugin skill uses managed Codex marker"
assert_contains "$PLUGIN_DIR/skills/distill/SKILL.md" '$distill' \
  "plugin skill documents native Codex invocation"
assert_contains "$PLUGIN_DIR/skills/distill/SKILL.md" 'defaulting to `~/.codex/distill`' \
  "plugin skill resolves default Codex distill directory"
assert_contains "$MARKETPLACE" '"path": "./plugins/aura-distill"' \
  "marketplace points at repo plugin package"
assert_contains "$MARKETPLACE" '"authentication": "ON_INSTALL"' \
  "marketplace declares authentication policy"

if [ -f "$VALIDATOR" ]; then
  if python3 "$VALIDATOR" "$PLUGIN_DIR" >/dev/null; then
    pass "plugin manifest validates"
  else
    fail "plugin manifest validates"
  fi
else
  fail "plugin validator is available"
fi

if [ "$FAIL" -eq 0 ]; then
  printf "\nResults: %d passed, 0 failed, %d total\n" "$PASS" "$PASS"
  exit 0
fi

total=$((PASS + FAIL))
printf "\nResults: %d passed, %d failed, %d total\n" "$PASS" "$FAIL" "$total"
exit 1
