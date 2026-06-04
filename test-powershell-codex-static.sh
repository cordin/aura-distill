#!/bin/bash
# Static regression tests for PowerShell Codex installer support.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PS1="$SCRIPT_DIR/install.ps1"

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

assert_contains() {
  local pattern="$1"
  local label="$2"
  if grep -Fq "$pattern" "$INSTALL_PS1"; then
    pass "$label"
  else
    fail "$label"
  fi
}

printf "\naura-distill PowerShell Codex static tests\n\n"

assert_contains "[ValidateSet('claude', 'codex')]" "PowerShell installer declares Codex target"
assert_contains "[switch]\$Uninstall" "PowerShell installer supports uninstall switch"
assert_contains "function Uninstall-Claude" "PowerShell installer handles default Claude uninstall"
assert_contains "AURA_DISTILL_REPO" "PowerShell installer supports repository override"
assert_contains "\$env:CODEX_HOME" "PowerShell installer resolves CODEX_HOME"
assert_contains ".agents') 'skills') 'distill'" "PowerShell installer targets native Codex skill path"
assert_contains "System.Text.UTF8Encoding \$false" "PowerShell installer writes Codex assets without UTF-8 BOM"
assert_contains "Render-CodexAsset 'codex/skills/distill/SKILL.md'" "PowerShell installer renders native Codex skill"
assert_contains "Render-CodexAsset 'codex/distill-adapter.md'" "PowerShell installer renders Codex adapter"
assert_contains "Render-CodexMonitor" "PowerShell installer renders Codex monitor from shared rules"
assert_contains "<!-- aura-distill:codex:start -->" "PowerShell installer writes managed AGENTS block"
assert_contains "Remove-ManagedCodexAgentsBlock" "PowerShell installer removes managed AGENTS block on uninstall"
assert_contains "Refusing to overwrite existing skill" "PowerShell installer refuses unrelated user-owned skill"
assert_contains "Preserved knowledge in \$CodexDistillDir" "PowerShell uninstall preserves Codex knowledge"
assert_contains "Codex Memories" "PowerShell AGENTS block preserves Codex Memories policy"

if [ "$FAIL" -eq 0 ]; then
  printf "\nResults: %d passed, 0 failed, %d total\n" "$PASS" "$PASS"
  exit 0
fi

total=$((PASS + FAIL))
printf "\nResults: %d passed, %d failed, %d total\n" "$PASS" "$FAIL" "$total"
exit 1
