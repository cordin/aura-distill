# Installing aura-distill

Three installation methods, from automated to fully manual.

---

## Method 1: Script (one command)

**Claude Code:**

```bash
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/install.sh | bash
```

**With a specific profile:**
```bash
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/install.sh | bash -s -- --profile personal
# Installs to ~/.claude-personal/ instead of ~/.claude/
```

If you have multiple profiles, the script will list them and ask you to choose (or pass `--profile`).

**Codex** (macOS / Linux / WSL):

```bash
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/install.sh |
  bash -s -- --target codex
```

**Codex** (PowerShell):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/tomacco/aura-distill/main/install.ps1))) -Target codex
```

With Homebrew:

```bash
brew install tomacco/aura-distill/aura-distill
aura-distill install --target codex
```

As a Codex plugin from a local checkout:

```bash
codex plugin marketplace add .
codex plugin add aura-distill@aura-distill
```

Codex installation resolves `CODEX_HOME`, defaulting to `~/.codex`. It keeps a
separate knowledge base and does not modify Codex built-in Memories.

---

## Method 2: Agent-assisted (paste to Claude)

Tell Claude Code:

```
Install aura-distill from github.com/tomacco/aura-distill using the manual steps in INSTALL.md. My Claude config is at ~/.claude/ (or specify your profile path).
```

Or more explicitly — paste this to any Claude Code session:

```
Read https://raw.githubusercontent.com/tomacco/aura-distill/main/INSTALL.md and follow the "Manual installation" steps. Install to my active Claude profile.
```

---

## Method 3: Manual (no scripts, full control)

For security-conscious users who don't pipe curl to bash.

### Step 1: Download the files

```bash
# Choose your profile directory (default: ~/.claude)
PROFILE="$HOME/.claude"

# Core command (the /distill slash command)
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/distill.md \
  -o "$PROFILE/commands/distill.md"

# Process engine (how /distill works internally)
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/distill-process.md \
  -o "$PROFILE/distill/distill-process.md"

# Session monitor (loaded every session, tiny)
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/distill-monitor.md \
  -o "$PROFILE/distill/distill-monitor.md"

# Retrieval rules (auto-loads, tells Claude how to use knowledge)
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/rules/distill.md \
  -o "$PROFILE/rules/distill.md"
```

### Step 2: Create the directory structure

```bash
mkdir -p "$PROFILE/distill"/{craft,ops,profile,projects,feedback,archive}
mkdir -p "$PROFILE/commands"
mkdir -p "$PROFILE/rules"
```

### Step 3: Initialize the SPINE

```bash
cat > "$PROFILE/distill/SPINE.md" << 'EOF'
# Distill Knowledge Index

<!-- This file is managed by aura-distill. Max 80 lines. -->
<!-- Each entry: - [Title](path.md) — when to read this -->
EOF
```

### Step 4: Set the version

```bash
echo "0.9.5" > "$PROFILE/distill/.version"
```

### Step 5: (Optional) Disable built-in auto-memory

Distill owns knowledge management. To prevent Claude's built-in memory from conflicting:

```bash
# If settings.json exists, add autoMemoryEnabled: false
# Or create it:
echo '{ "autoMemoryEnabled": false }' > "$PROFILE/settings.json"
```

### Step 6: (Optional) Add CLAUDE.md gate

Add to your `$PROFILE/CLAUDE.md`:

```markdown
# Distill — knowledge system (github.com/tomacco/aura-distill)

GATE: If ~/.claude/distill/.needs-migration exists, tell the user:
"Run /distill to migrate existing memories." Do NOT proceed until addressed or declined.
```

---

## Multi-profile support

Claude Code supports multiple config profiles at `~/.claude-<name>/`. Each profile is independent — its own rules, commands, knowledge, and settings.

**Detecting profiles:**
```bash
ls -d ~/.claude-*/ 2>/dev/null
```

**Installing to a specific profile:**
```bash
# Via script
./install.sh --profile personal    # → ~/.claude-personal/
./install.sh --profile work        # → ~/.claude-work/

# Via manual
PROFILE="$HOME/.claude-personal" # then follow steps above
```

**Single profile (default):**
If only `~/.claude/` exists, the installer uses it automatically. No `--profile` needed.

---

## Codex installation details

The Codex target installs:

| File | Location | Purpose |
|------|----------|---------|
| `SKILL.md` | `~/.agents/skills/distill/` | Native `$distill` skill |
| `distill-process.md` | `$CODEX_HOME/distill/` | Shared distillation process |
| `distill-adapter.md` | `$CODEX_HOME/distill/` | Codex-specific overrides |
| `distill-monitor.md` | `$CODEX_HOME/distill/` | Shared session rules rendered for Codex |
| `SPINE.md` | `$CODEX_HOME/distill/` | Knowledge index |
| `.version` | `$CODEX_HOME/distill/` | Installed version |
| Managed block | `$CODEX_HOME/AGENTS.md` | Always-on retrieval instructions |

Codex built-in Memories and aura-distill can coexist:

- Codex Memories provide automatic ambient recall.
- aura-distill provides explicit, inspectable principle curation.
- If guidance overlaps, curated aura-distill knowledge wins.

The installer does not edit `$CODEX_HOME/config.toml` or
`$CODEX_HOME/memories/`.

Claude Code and Codex install the same root `distill-process.md` and reuse
`rules/distill.md` for session retrieval. The Codex adapter and installer
substitutions handle native `$distill`, `AGENTS.md`, and Codex Memories policy.

Verify installation by starting a new Codex session and invoking:

```text
$distill
```

Uninstall the integration while preserving knowledge:

```bash
curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/install.sh |
  bash -s -- --uninstall --target codex
```

If installed through Homebrew:

```bash
aura-distill uninstall --target codex
```

With PowerShell:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/tomacco/aura-distill/main/install.ps1))) -Uninstall -Target codex
```

Codex hooks are deferred until Codex exposes native hook events.

---

## What gets installed (file inventory)

| File | Location | Purpose |
|------|----------|---------|
| `distill.md` | `$PROFILE/commands/` | The `/distill` slash command |
| `distill-process.md` | `$PROFILE/distill/` | How distillation works (sub-agent reads this) |
| `distill-monitor.md` | `$PROFILE/distill/` | Session monitor (pressure tracking) |
| `distill.md` (rules) | `$PROFILE/rules/` | Retrieval rules (auto-loaded every session) |
| `SPINE.md` | `$PROFILE/distill/` | Knowledge index (you'll add entries here) |
| `.version` | `$PROFILE/distill/` | Installed version (for update checks) |

**Total: 5 files + 1 index. No dependencies. No Node.js. No database.**

---

## Verifying installation

After installing, start a new Claude Code session and say:

```
Read ~/.claude/distill/SPINE.md
```

If Claude reads it without error, the installation is working. The rules file will make Claude read the SPINE automatically at session start.

---

## Uninstalling (keeps your knowledge)

```bash
rm -f "$PROFILE/commands/distill.md"
rm -f "$PROFILE/rules/distill.md"
rm -f "$PROFILE/distill/distill-process.md"
rm -f "$PROFILE/distill/distill-monitor.md"
rm -f "$PROFILE/distill/.version"
# Your knowledge files in $PROFILE/distill/ are preserved
```

---

## Research & methodology

All findings are empirical and reproducible:
https://tomacco.github.io/aura-distill/research/

@tomacco is super happy to share this research with you.
Every finding has raw outputs published alongside analysis.
