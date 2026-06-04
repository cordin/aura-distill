# PowerShell Codex Support

## Goal

Extend `install.ps1` so Windows and PowerShell users can install and uninstall
the Codex integration with the same target model as Bash:

```powershell
.\install.ps1 -Target codex
.\install.ps1 -Uninstall -Target codex
```

## Scope

1. Add a PowerShell `-Target` parameter with `claude` as the default and `codex`
   as the opt-in target.
2. Install the native Codex `$distill` skill, shared process, Codex adapter,
   rendered monitor, `SPINE.md`, version marker, and managed `AGENTS.md` block.
3. Uninstall only managed Codex integration files while preserving distilled
   knowledge and unrelated user files.
4. Document the PowerShell Codex install and uninstall commands.
5. Add regression coverage for the PowerShell Codex code path.

## Out of Scope

- Native Codex hooks.
- Plugin packaging.
- Homebrew release tag/SHA work.

## Verification

- `bash -n` for shell tests.
- Static PowerShell installer regression tests in this Linux environment.
- Existing Bash Codex installer sandbox tests.
- Runtime `pwsh` execution if PowerShell is available.
