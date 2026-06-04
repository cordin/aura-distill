# Codex Plugin Package

## Goal

Package aura-distill as a repo-contained Codex plugin so users can install the
native `$distill` skill through Codex's plugin mechanism instead of only through
the file-copy installers.

## Scope

1. Add a validated plugin manifest under `plugins/aura-distill/`.
2. Bundle the existing Codex `$distill` skill in the plugin package.
3. Add a repo-local marketplace entry for Codex plugin installation.
4. Document plugin installation as an alternative to Bash, PowerShell, and
   Homebrew installers.
5. Add lightweight validation for the plugin package.

## Out of Scope

- Native Codex hooks.
- Replacing the current Bash/PowerShell installers.
- Personal marketplace writes under `~/.agents/plugins`.
- Release tag/SHA updates.

## Verification

- Validate the plugin manifest with the local Codex plugin validator.
- Run static checks for plugin files.
- Run existing Codex installer sandbox tests to catch regressions.
