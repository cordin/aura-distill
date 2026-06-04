# aura-distill installer (Windows / PowerShell)
# https://github.com/tomacco/aura-distill
#
# Usage:
#   irm https://raw.githubusercontent.com/tomacco/aura-distill/main/install.ps1 | iex
#   .\install.ps1 -Target codex
#   .\install.ps1 -Uninstall -Target codex

param(
    [ValidateSet('claude', 'codex')]
    [string]$Target = 'claude',

    [switch]$Uninstall,

    [string]$Repo = $(if ($env:AURA_DISTILL_REPO) { $env:AURA_DISTILL_REPO } else { 'https://raw.githubusercontent.com/tomacco/aura-distill/main' })
)

$ErrorActionPreference = 'Stop'

$Version  = '1.1.3'
$Build    = '20260515-01'

# Resolve home (works on PS 5.1 and PS 7+, Windows and cross-platform)
$UserHome    = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$ClaudeHome  = Join-Path $UserHome '.claude'
$CmdDir      = Join-Path $ClaudeHome 'commands'
$DistillDir  = Join-Path $ClaudeHome 'distill'
$RulesDir    = Join-Path $ClaudeHome 'rules'
$ClaudeMd    = Join-Path $ClaudeHome 'CLAUDE.md'
$SettingsJson = Join-Path $ClaudeHome 'settings.json'

$CodexHome       = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $UserHome '.codex' }
$CodexDistillDir = Join-Path $CodexHome 'distill'
$CodexSkillDir   = Join-Path (Join-Path (Join-Path $UserHome '.agents') 'skills') 'distill'
$CodexSkillFile  = Join-Path $CodexSkillDir 'SKILL.md'
$CodexAgentsMd   = Join-Path $CodexHome 'AGENTS.md'

$EmDash = [char]0x2014
$DistillLine = @"
# Distill $EmDash knowledge system (github.com/tomacco/aura-distill)

GATE: If ~/.claude/distill/.needs-migration exists, tell the user: "Run /distill to migrate existing memories." Do NOT proceed until addressed or declined.
"@

# Enable ANSI escape sequences on Windows conhost when available
try {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $Host.UI.RawUI.ForegroundColor = $Host.UI.RawUI.ForegroundColor  # touch to ensure VT init
    }
} catch {}

$ESC    = [char]27
$CYAN   = "$ESC[0;36m"
$PURPLE = "$ESC[0;35m"
$GREEN  = "$ESC[0;32m"
$RED    = "$ESC[0;31m"
$YELLOW = "$ESC[0;33m"
$DIM    = "$ESC[2m"
$BOLD   = "$ESC[1m"
$RESET  = "$ESC[0m"

function Write-Done  { param([string]$m) Write-Host "  ${GREEN}OK${RESET}  $m" }
function Write-Skip  { param([string]$m) Write-Host "  ${DIM} . ${RESET} $m" }
function Write-Warn  { param([string]$m) Write-Host "  ${YELLOW}!${RESET}  $m" }
function Write-Fail  { param([string]$m) Write-Host "  ${RED}x${RESET}  $m" }
function Write-Info  { param([string]$m) Write-Host "  ${CYAN}i${RESET}  $m" }

function Write-Header {
    Clear-Host
    Write-Host ''
    Write-Host "${PURPLE}        ,--------------------------------------."
    Write-Host '        |                                      |'
    Write-Host '        |      aura-distill                  |'
    Write-Host '        |                                      |'
    Write-Host "        '--------------------------------------'${RESET}"
    Write-Host ''
    Write-Host "  ${DIM}every session makes all sessions better${RESET}"
    Write-Host "  ${DIM}say what matters. it's listening.${RESET}"
    Write-Host ''
    Write-Host "  ${DIM}v$Version (build $Build)${RESET}"
    Write-Host ''
}

function Write-Section {
    param([string]$title)
    Write-Host ''
    Write-Host "  ${PURPLE}==${RESET} ${BOLD}$title${RESET}"
    Write-Host ''
}

function Get-File {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    # PS 5.1 requires -UseBasicParsing; harmless on PS 7+
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
}

function Get-AssetText {
    param([Parameter(Mandatory=$true)][string]$Asset)
    $response = Invoke-WebRequest -Uri "$Repo/$Asset" -UseBasicParsing
    return [string]$response.Content
}

function Set-TextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content,
        [switch]$NoNewline
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    if ($NoNewline) {
        [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding $false))
    } else {
        [System.IO.File]::WriteAllText($Path, ($Content + "`n"), (New-Object System.Text.UTF8Encoding $false))
    }
}

function Render-CodexAsset {
    param(
        [Parameter(Mandatory=$true)][string]$Asset,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    try {
        $content = (Get-AssetText $Asset).Replace('{DISTILL_DIR}', $CodexDistillDir)
        Set-TextFile -Path $Destination -Content $content
    } catch {
        Write-Fail "Failed to download $Asset from $Repo"
        Write-Fail 'Set AURA_DISTILL_REPO to the matching repository branch and try again.'
        throw
    }
}

function Render-CodexMonitor {
    param([Parameter(Mandatory=$true)][string]$Destination)
    try {
        $content = (Get-AssetText 'rules/distill.md').Replace('{DISTILL_DIR}', $CodexDistillDir)
        $content = $content.Replace('active Claude config', 'active Codex home')
        $content = $content.Replace('Typically `~/.claude/distill/` for the default profile, or `~/.claude-<name>/distill/` for named profiles.', 'Installed under `$CODEX_HOME/distill/` (typically `~/.codex/distill/`).')
        $content = $content.Replace('want to /distill?', 'want to $distill?')
        $content = $content.Replace('Strongly recommend /distill', 'Strongly recommend $distill')
        $content = $content.Replace('for `/distill`', 'for `$distill`')
        $content = $content.Replace('by /distill', 'by $distill')
        $content = $content.Replace('first /distill run', 'first $distill run')
        Set-TextFile -Path $Destination -Content $content
    } catch {
        Write-Fail "Failed to download rules/distill.md from $Repo"
        Write-Fail 'Set AURA_DISTILL_REPO to the matching repository branch and try again.'
        throw
    }
}

function Remove-ManagedCodexAgentsBlock {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) { return }

    $lines = Get-Content $Path
    $kept = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $lines) {
        if ($line -eq '<!-- aura-distill:codex:start -->') {
            $skip = $true
            continue
        }
        if ($line -eq '<!-- aura-distill:codex:end -->') {
            $skip = $false
            continue
        }
        if (-not $skip) {
            $kept.Add($line)
        }
    }
    Set-Content -Path $Path -Value $kept -Encoding utf8
}

function Uninstall-Claude {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $CmdDir 'distill.md')
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $RulesDir 'distill.md')
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $DistillDir 'distill-process.md')
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $DistillDir 'distill-monitor.md')
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $DistillDir '.version')
    Write-Done "Uninstalled Claude Code integration from $ClaudeHome"
    Write-Info "Preserved knowledge in $DistillDir"
}

function Install-Codex {
    if ($Uninstall) {
        if ((Test-Path $CodexSkillFile) -and ((Get-Content $CodexSkillFile -Raw) -match '<!-- aura-distill:codex-skill -->')) {
            Remove-Item -Force $CodexSkillFile
        }
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $CodexDistillDir 'distill-process.md')
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $CodexDistillDir 'distill-adapter.md')
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $CodexDistillDir 'distill-monitor.md')
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $CodexDistillDir '.version')
        Remove-ManagedCodexAgentsBlock $CodexAgentsMd
        Write-Done "Uninstalled Codex integration from $CodexHome"
        Write-Info "Preserved knowledge in $CodexDistillDir"
        return
    }

    Write-Info "Installing Codex integration to: $CodexHome"
    Write-Host ''

    $codexVersionFile = Join-Path $CodexDistillDir '.version'
    if (Test-Path $codexVersionFile) {
        $existingVersion = (Get-Content $codexVersionFile -Raw).Trim()
        Write-Info "Existing installation: v$existingVersion -> v$Version"
        Write-Host ''
    }

    Write-Section 'Core files'

    foreach ($d in @($CodexDistillDir,
                     (Join-Path $CodexDistillDir 'craft'),
                     (Join-Path $CodexDistillDir 'ops'),
                     (Join-Path $CodexDistillDir 'profile'),
                     (Join-Path $CodexDistillDir 'projects'),
                     (Join-Path $CodexDistillDir 'feedback'),
                     (Join-Path $CodexDistillDir 'archive'),
                     $CodexSkillDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    }

    if ((Test-Path $CodexSkillFile) -and ((Get-Item $CodexSkillFile).Length -gt 0) -and ((Get-Content $CodexSkillFile -Raw) -notmatch '<!-- aura-distill:codex-skill -->')) {
        Write-Fail "Refusing to overwrite existing skill: $CodexSkillFile"
        Write-Fail 'Move or rename that skill, then run the installer again.'
        exit 1
    }

    Render-CodexAsset 'codex/skills/distill/SKILL.md' $CodexSkillFile
    Write-Done "distill skill ${DIM}($CodexSkillFile)${RESET}"

    Render-CodexAsset 'distill-process.md' (Join-Path $CodexDistillDir 'distill-process.md')
    Write-Done "distill-process.md ${DIM}(shared process engine)${RESET}"

    Render-CodexAsset 'codex/distill-adapter.md' (Join-Path $CodexDistillDir 'distill-adapter.md')
    Write-Done "distill-adapter.md ${DIM}(Codex overrides)${RESET}"

    Render-CodexMonitor (Join-Path $CodexDistillDir 'distill-monitor.md')
    Write-Done "distill-monitor.md ${DIM}(shared session rules)${RESET}"

    Set-TextFile -Path $codexVersionFile -Content $Version -NoNewline

    $codexSpinePath = Join-Path $CodexDistillDir 'SPINE.md'
    if (-not (Test-Path $codexSpinePath)) {
        $spine = @(
            '# Distill Knowledge Index',
            '',
            '<!-- This file is managed by aura-distill. Max 80 lines. -->',
            '<!-- Each entry: - [Title](path.md) - when to read this -->'
        ) -join "`n"
        Set-TextFile -Path $codexSpinePath -Content $spine
        Write-Done "SPINE.md ${DIM}(knowledge index)${RESET}"
    } else {
        Write-Skip "SPINE.md ${DIM}(preserved)${RESET}"
    }

    Write-Section 'Session integration'

    if (-not (Test-Path $CodexHome)) { New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null }
    if (-not (Test-Path $CodexAgentsMd)) { New-Item -ItemType File -Force -Path $CodexAgentsMd | Out-Null }
    $codexSpineForAgents = (Join-Path $CodexDistillDir 'SPINE.md')
    $codexMonitorForAgents = (Join-Path $CodexDistillDir 'distill-monitor.md')

    $agentsContent = Get-Content $CodexAgentsMd -Raw
    if ($agentsContent -match '<!-- aura-distill:codex:start -->') {
        Write-Skip "AGENTS.md ${DIM}(already configured)${RESET}"
    } else {
        $block = @"

<!-- aura-distill:codex:start -->
# Distill - curated knowledge system (github.com/tomacco/aura-distill)

Read $codexSpineForAgents at session start. Before the first major action in a
domain, read matching Tier 2 files referenced by the SPINE. Treat aura-distill
as authoritative when curated guidance overlaps with ambient Codex Memories.
Do not modify Codex Memories. Track corrections, failures, surprises, and
explicit preferences as signals; recommend `$distill when several accumulate.
Read $codexMonitorForAgents for the complete session monitor.
<!-- aura-distill:codex:end -->
"@
        Add-Content -Path $CodexAgentsMd -Value $block -Encoding utf8
        Write-Done 'AGENTS.md configured'
    }

    Write-Host ''
    Write-Host "  ${GREEN}---------------------------------------${RESET}"
    Write-Host ''
    Write-Host "  ${GREEN}${BOLD}Installed for Codex${RESET}"
    Write-Host "  ${DIM}Zero dependencies. Just files.${RESET}"
    Write-Host ''
    Write-Host "  ${DIM}Version:  ${RESET}v$Version"
    Write-Host "  ${DIM}Skill:    ${RESET}`$distill"
    Write-Host "  ${DIM}Knowledge:${RESET} $CodexDistillDir"
    Write-Host ''
    Write-Host "  ${DIM}Uninstall (keeps your learnings):${RESET}"
    Write-Host "    ${DIM}.\install.ps1 -Uninstall -Target codex${RESET}"
    Write-Host ''
}

# === MAIN ===

Write-Header

if ($Target -eq 'codex') {
    Install-Codex
    exit 0
}

if ($Uninstall) {
    Uninstall-Claude
    exit 0
}

# Detect existing installation
$existingVersion = ''
$versionFile = Join-Path $DistillDir '.version'
if (Test-Path $versionFile) {
    $existingVersion = (Get-Content $versionFile -Raw).Trim()
    Write-Info "Existing installation: v$existingVersion -> v$Version"
    Write-Host ''
}

Write-Section 'Core files'

# Ensure directories exist
foreach ($d in @($CmdDir, $DistillDir,
                 (Join-Path $DistillDir 'craft'),
                 (Join-Path $DistillDir 'ops'),
                 (Join-Path $DistillDir 'profile'),
                 (Join-Path $DistillDir 'projects'),
                 (Join-Path $DistillDir 'feedback'),
                 (Join-Path $DistillDir 'archive'))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

Get-File "$Repo/distill.md"          (Join-Path $CmdDir 'distill.md')
Write-Done "distill.md ${DIM}(command)${RESET}"

Get-File "$Repo/distill-process.md"  (Join-Path $DistillDir 'distill-process.md')
Write-Done "distill-process.md ${DIM}(process engine)${RESET}"

Get-File "$Repo/distill-monitor.md"  (Join-Path $DistillDir 'distill-monitor.md')
Write-Done "distill-monitor.md ${DIM}(session monitor)${RESET}"

# Version
Set-Content -Path $versionFile -Value $Version -Encoding utf8 -NoNewline

# Spine
$spinePath = Join-Path $DistillDir 'SPINE.md'
if (-not (Test-Path $spinePath)) {
    $spine = @(
        '# Distill Knowledge Index',
        '',
        '<!-- This file is managed by aura-distill. Max 80 lines. -->',
        '<!-- Each entry: - [Title](path.md) -- when to read this -->'
    ) -join "`n"
    Set-Content -Path $spinePath -Value $spine -Encoding utf8
    Write-Done "SPINE.md ${DIM}(knowledge index)${RESET}"
} else {
    Write-Skip "SPINE.md ${DIM}(preserved)${RESET}"
}

# === KNOWLEDGE RETRIEVAL (rules file) ===

Write-Section 'Knowledge retrieval'

if (-not (Test-Path $RulesDir)) { New-Item -ItemType Directory -Force -Path $RulesDir | Out-Null }
Get-File "$Repo/rules/distill.md" (Join-Path $RulesDir 'distill.md')
Write-Done "rules/distill.md ${DIM}(auto-loads every session)${RESET}"

# === SESSION INTEGRATION ===

Write-Section 'Session integration'

# Disable auto-memory (distill owns knowledge management)
if (Test-Path $SettingsJson) {
    try {
        $raw = Get-Content $SettingsJson -Raw
        $settings = $raw | ConvertFrom-Json
        if ($settings.PSObject.Properties.Name -contains 'autoMemoryEnabled') {
            Write-Skip 'Auto-memory already configured in settings.json'
        } else {
            $settings | Add-Member -NotePropertyName 'autoMemoryEnabled' -NotePropertyValue $false -Force
            $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $SettingsJson -Encoding utf8
            Write-Done "Disabled auto-memory ${DIM}(distill owns knowledge)${RESET}"
        }
    } catch {
        Write-Warn "Could not parse $SettingsJson -- leaving untouched. Add `"autoMemoryEnabled`": false manually."
    }
} else {
    '{ "autoMemoryEnabled": false }' | Set-Content -Path $SettingsJson -Encoding utf8
    Write-Done 'Created settings.json with auto-memory disabled'
}

if (Test-Path $ClaudeMd) {
    $claudeMdContent = Get-Content $ClaudeMd -Raw
    if ($claudeMdContent -match 'aura-distill') {
        Write-Done "CLAUDE.md ${DIM}(already configured)${RESET}"
    } elseif ($claudeMdContent -match 'distill') {
        # Older reference -- strip lines containing 'distill', then append fresh block
        $cleaned = (Get-Content $ClaudeMd | Where-Object { $_ -notmatch 'distill' }) -join "`n"
        Set-Content -Path $ClaudeMd -Value ($cleaned + "`n`n" + $DistillLine) -Encoding utf8
        Write-Done "CLAUDE.md ${DIM}(upgraded)${RESET}"
    } else {
        Add-Content -Path $ClaudeMd -Value ("`n" + $DistillLine) -Encoding utf8
        Write-Done 'CLAUDE.md configured'
    }
} else {
    Set-Content -Path $ClaudeMd -Value $DistillLine -Encoding utf8
    Write-Done 'Created CLAUDE.md'
}

# === MEMORY MIGRATION CHECK ===

$memoryFiles = @()
if (Test-Path $ClaudeHome) {
    $memoryFiles = Get-ChildItem -Path $ClaudeHome -Filter '*.md' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\memory\\' -and $_.FullName -notmatch '\\distill\\' }
}
$migratedFlag = Join-Path $DistillDir '.migrated'
if ($memoryFiles.Count -gt 0 -and -not (Test-Path $migratedFlag)) {
    Write-Host ''
    Write-Host "  ${CYAN}==${RESET} ${BOLD}Existing memories detected${RESET}"
    Write-Host ''
    Write-Host "  Found ${BOLD}$($memoryFiles.Count)${RESET} memory files from Claude's built-in system."
    Write-Host "  Since distill now owns knowledge management, these won't be"
    Write-Host '  read by the auto-memory system anymore.'
    Write-Host ''
    Write-Host "  ${BOLD}On your next session, run ${CYAN}/distill${RESET}${BOLD} -- it will:${RESET}"
    Write-Host '    - Read your existing memories'
    Write-Host "    - Ingest them into distill's tiered system"
    Write-Host '    - Apply quality checks and proper categorization'
    Write-Host '    - Your old files stay untouched (as backup)'
    Write-Host ''
    New-Item -ItemType File -Path (Join-Path $DistillDir '.needs-migration') -Force | Out-Null
}

# === COMPLETE ===

Write-Host ''
Write-Host ''
Write-Host "  ${GREEN}---------------------------------------${RESET}"
Write-Host ''
Write-Host "  ${GREEN}${BOLD}Installed${RESET}"
Write-Host "  ${DIM}Zero dependencies. Just files.${RESET}"
Write-Host ''
Write-Host "  ${DIM}Version:  ${RESET}v$Version"
Write-Host "  ${DIM}Command:  ${RESET}/distill"
Write-Host "  ${DIM}Knowledge:${RESET} $DistillDir"
Write-Host ''
if ($existingVersion) {
    Write-Host "  ${CYAN}Upgraded${RESET} v$existingVersion -> v$Version"
    Write-Host ''
}
Write-Host "  ${DIM}Uninstall (keeps your learnings):${RESET}"
Write-Host "    ${DIM}Remove-Item -Recurse -Force `$HOME\.claude\distill, `$HOME\.claude\commands\distill.md, `$HOME\.claude\rules\distill.md${RESET}"
Write-Host ''
Write-Host "  ${PURPLE}say what matters. it's listening.${RESET}"
Write-Host ''
