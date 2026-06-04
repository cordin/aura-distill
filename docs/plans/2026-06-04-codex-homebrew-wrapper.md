# Codex Homebrew Wrapper Support

## Goal

Add Codex support to the Homebrew-installed `aura-distill` wrapper so users can
install and uninstall the Codex integration with the same `--target codex`
interface as the direct Bash installer.

## Scope

1. Package the Codex-specific installer assets in the Homebrew formula.
2. Update the generated `aura-distill` wrapper to delegate uninstall to
   `install.sh` instead of maintaining a Claude-only removal path.
3. Document Homebrew Codex installation and uninstall usage.
4. Add lightweight tests for formula packaging and wrapper behavior.

## Out of Scope

- PowerShell Codex support.
- Codex hooks.
- Codex plugin packaging.
- Homebrew release tag/version updates.

## Verification

- `ruby -c homebrew/Formula/aura-distill.rb`
- New Homebrew wrapper regression test
- `./test-codex-sandbox.sh`
