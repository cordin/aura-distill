# Codex Installer Fetch Failure Hotfix

## Summary

Fix Codex installation failures when an asset download returns 404. The current
Codex installer streams downloads directly into managed destination files, so a
failed fetch can leave an empty `SKILL.md` while still printing later success
messages.

## Implementation

1. Keep the existing `AURA_DISTILL_REPO` override contract.
2. Add atomic Codex asset rendering helpers that write to a temporary file and
   move it into place only after the download and substitutions succeed.
3. Use those helpers for the Codex skill, shared process, adapter, and rendered
   session monitor.
4. Add a sandbox regression that intentionally points the installer at a repo
   missing Codex assets and verifies an existing managed skill is not
   truncated.

## Test Plan

- `bash -n install.sh`
- `bash -n test-codex-sandbox.sh`
- `./test-codex-sandbox.sh`
- `AURA_DISTILL_REPO="file://$PWD" ./test-sandbox.sh install`
- Repair the local Codex install with `AURA_DISTILL_REPO="file://$PWD"
  ./install.sh --target codex`
