#!/bin/bash
# aura-distill installer
# https://github.com/tomacco/aura-distill

set -e




VERSION="1.1.3"

BUILD="20260518-01"
REPO="${AURA_DISTILL_REPO:-https://raw.githubusercontent.com/tomacco/aura-distill/main}"
# Profile paths are set dynamically after profile detection (see below)
PROFILE_DIR=""
TARGET="claude"
ACTION="install"
DISTILL_LINE='# Distill — knowledge system (github.com/tomacco/aura-distill)

GATE: If ~/.claude/distill/.needs-migration exists, tell the user: "Run /distill to migrate existing memories." Do NOT proceed until addressed or declined.'

# ═══ COLORS & FORMATTING ═══
CYAN=$(printf '\033[0;36m')
PURPLE=$(printf '\033[0;35m')
GREEN=$(printf '\033[0;32m')
DIM=$(printf '\033[2m')
BOLD=$(printf '\033[1m')
RESET=$(printf '\033[0m')
RED=$(printf '\033[0;31m')
YELLOW=$(printf '\033[0;33m')

# ═══ ANIMATION HELPERS ═══

spinner() {
  local pid=$1
  local msg=$2
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0
  tput civis 2>/dev/null  # hide cursor
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  %s %s   " "${frames[$i]}" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done
  wait "$pid"
  local exit_code=$?
  printf "\r                                                              \r"
  tput cnorm 2>/dev/null  # show cursor
  return $exit_code
}

done_msg() {
  echo "  ${GREEN}✓${RESET} $1"
}

skip_msg() {
  echo "  ${DIM}·${RESET} $1"
}

warn_msg() {
  echo "  ${YELLOW}⚠${RESET} $1"
}

fail_msg() {
  echo "  ${RED}✗${RESET} $1"
}

info_msg() {
  echo "  ${CYAN}ℹ${RESET} $1"
}

# ═══ HEADER ANIMATION ═══

show_header() {
  clear
  echo ""
  printf "${PURPLE}"
  echo "        ╭──────────────────────────────────────╮"
  echo "        │                                      │"
  echo "        │        ░█▀█░█░█░█▀▄░█▀█              │"
  echo "        │        ░█▀█░█░█░█▀▄░█▀█              │"
  echo "        │        ░▀░▀░▀▀▀░▀░▀░▀░▀              │"
  echo "        │                                      │"
  echo "        │      ░█▀▄░▀█▀░█▀▀░▀█▀░▀█▀░█░░░█░░    │"
  echo "        │      ░█░█░░█░░▀▀█░░█░░░█░░█░░░█░░    │"
  echo "        │      ░▀▀░░▀▀▀░▀▀▀░░▀░░▀▀▀░▀▀▀░▀▀▀    │"
  echo "        │                                      │"
  echo "        ╰──────────────────────────────────────╯"
  printf "${RESET}"
  echo ""
  printf "  ${DIM}every session makes all sessions better${RESET}\n"
  printf "  ${DIM}say what matters. it's listening.${RESET}\n"
  echo ""
  printf "  ${DIM}v${VERSION} (build ${BUILD})${RESET}\n"
  echo ""
}

show_section() {
  echo ""
  printf "  ${PURPLE}━━${RESET} ${BOLD}%s${RESET}\n" "$1"
  echo ""
}


# ═══ PROFILE DETECTION ═══

# Parse installer arguments
PROFILE_NAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile) PROFILE_NAME="$2"; shift 2 ;;
        --profile=*) PROFILE_NAME="${1#*=}"; shift ;;
        --target) TARGET="$2"; shift 2 ;;
        --target=*) TARGET="${1#*=}"; shift ;;
        --uninstall) ACTION="uninstall"; shift ;;
        *) shift ;;
    esac
done

if [ "$TARGET" != "claude" ] && [ "$TARGET" != "codex" ]; then
    fail_msg "Unknown target '$TARGET'. Expected claude or codex."
    exit 1
fi

fetch_asset() {
    curl -fsSL "$REPO/$1"
}

remove_managed_codex_agents_block() {
    local agents_md="$1"
    local temp_file
    temp_file=$(mktemp)
    awk '
        $0 == "<!-- aura-distill:codex:start -->" { skip = 1; next }
        $0 == "<!-- aura-distill:codex:end -->" { skip = 0; next }
        !skip { print }
    ' "$agents_md" > "$temp_file"
    mv "$temp_file" "$agents_md"
}

install_codex() {
    local codex_home="${CODEX_HOME:-$HOME/.codex}"
    local distill_dir="$codex_home/distill"
    local skill_dir="$HOME/.agents/skills/distill"
    local agents_md="$codex_home/AGENTS.md"
    local existing_version=""

    if [ "$ACTION" = "uninstall" ]; then
        if [ -f "$skill_dir/SKILL.md" ] &&
           grep -q '<!-- aura-distill:codex-skill -->' "$skill_dir/SKILL.md"; then
            rm -f "$skill_dir/SKILL.md"
        fi
        rm -f "$distill_dir/distill-process.md"
        rm -f "$distill_dir/distill-adapter.md"
        rm -f "$distill_dir/distill-monitor.md"
        rm -f "$distill_dir/.version"
        if [ -f "$agents_md" ]; then
            remove_managed_codex_agents_block "$agents_md"
        fi
        done_msg "Uninstalled Codex integration from ${codex_home}"
        info_msg "Preserved knowledge in ${distill_dir}"
        return
    fi

    info_msg "Installing Codex integration to: ${codex_home}"
    echo ""

    if [ -f "$distill_dir/.version" ]; then
        existing_version=$(cat "$distill_dir/.version")
        info_msg "Existing installation: v${existing_version} → v${VERSION}"
        echo ""
    fi

    show_section "Core files"

    mkdir -p "$distill_dir"/{craft,ops,profile,projects,feedback,archive}
    mkdir -p "$skill_dir"

    if [ -f "$skill_dir/SKILL.md" ] &&
       ! grep -q '<!-- aura-distill:codex-skill -->' "$skill_dir/SKILL.md"; then
        fail_msg "Refusing to overwrite existing skill: $skill_dir/SKILL.md"
        fail_msg "Move or rename that skill, then run the installer again."
        exit 1
    fi

    fetch_asset "codex/skills/distill/SKILL.md" |
        sed "s|{DISTILL_DIR}|$distill_dir|g" > "$skill_dir/SKILL.md"
    done_msg "distill skill ${DIM}($skill_dir/SKILL.md)${RESET}"

    fetch_asset "distill-process.md" |
        sed "s|{DISTILL_DIR}|$distill_dir|g" > "$distill_dir/distill-process.md"
    done_msg "distill-process.md ${DIM}(shared process engine)${RESET}"

    fetch_asset "codex/distill-adapter.md" |
        sed "s|{DISTILL_DIR}|$distill_dir|g" > "$distill_dir/distill-adapter.md"
    done_msg "distill-adapter.md ${DIM}(Codex overrides)${RESET}"

    fetch_asset "rules/distill.md" |
        sed -e "s|{DISTILL_DIR}|$distill_dir|g" \
            -e 's|active Claude config|active Codex home|g' \
            -e 's|Typically `~/.claude/distill/` for the default profile, or `~/.claude-<name>/distill/` for named profiles.|Installed under `$CODEX_HOME/distill/` (typically `~/.codex/distill/`).|g' \
            -e 's|/distill|$distill|g' > "$distill_dir/distill-monitor.md"
    done_msg "distill-monitor.md ${DIM}(shared session rules)${RESET}"

    echo "$VERSION" > "$distill_dir/.version"

    if [ ! -f "$distill_dir/SPINE.md" ]; then
        echo "# Distill Knowledge Index" > "$distill_dir/SPINE.md"
        echo "" >> "$distill_dir/SPINE.md"
        echo "<!-- This file is managed by aura-distill. Max 80 lines. -->" >> "$distill_dir/SPINE.md"
        echo "<!-- Each entry: - [Title](path.md) - when to read this -->" >> "$distill_dir/SPINE.md"
        done_msg "SPINE.md ${DIM}(knowledge index)${RESET}"
    else
        skip_msg "SPINE.md ${DIM}(preserved)${RESET}"
    fi

    show_section "Session integration"

    mkdir -p "$codex_home"
    touch "$agents_md"
    if grep -q '<!-- aura-distill:codex:start -->' "$agents_md" 2>/dev/null; then
        skip_msg "AGENTS.md ${DIM}(already configured)${RESET}"
    else
        cat >> "$agents_md" <<EOF

<!-- aura-distill:codex:start -->
# Distill - curated knowledge system (github.com/tomacco/aura-distill)

Read $distill_dir/SPINE.md at session start. Before the first major action in a
domain, read matching Tier 2 files referenced by the SPINE. Treat aura-distill
as authoritative when curated guidance overlaps with ambient Codex Memories.
Do not modify Codex Memories. Track corrections, failures, surprises, and
explicit preferences as signals; recommend \$distill when several accumulate.
Read $distill_dir/distill-monitor.md for the complete session monitor.
<!-- aura-distill:codex:end -->
EOF
        done_msg "AGENTS.md configured"
    fi

    echo ""
    printf "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    echo ""
    printf "  ${GREEN}${BOLD}Installed for Codex${RESET}\n"
    printf "  ${DIM}Zero dependencies. Just files.${RESET}\n"
    echo ""
    printf "  ${DIM}Version:  ${RESET}v${VERSION}\n"
    printf "  ${DIM}Skill:    ${RESET}\$distill\n"
    printf "  ${DIM}Knowledge:${RESET} %s\n" "$distill_dir"
    echo ""
    printf "  ${DIM}Uninstall (keeps your learnings):${RESET}\n"
    printf "    ${DIM}curl -sL https://raw.githubusercontent.com/tomacco/aura-distill/main/install.sh | bash -s -- --uninstall --target codex${RESET}\n"
    echo ""
}

# Detect available profiles
detect_profiles() {
    local profiles=()
    [ -d "$HOME/.claude" ] && profiles+=("default:$HOME/.claude")
    for dir in "$HOME"/.claude-*/; do
        [ -d "$dir" ] || continue
        local name=$(basename "$dir" | sed 's/^\.claude-//')
        # Skip test/internal profiles
        [[ "$name" == *"isolation"* || "$name" == *"hidden"* || "$name" == *"backup"* ]] && continue
        profiles+=("$name:$dir")
    done
    echo "${profiles[@]}"
}

resolve_profile() {
    local profiles=($(detect_profiles))
    local count=${#profiles[@]}

    # If --profile was passed, use it
    if [ -n "$PROFILE_NAME" ]; then
        if [ "$PROFILE_NAME" = "default" ]; then
            PROFILE_DIR="$HOME/.claude"
        else
            PROFILE_DIR="$HOME/.claude-${PROFILE_NAME}"
        fi
        if [ ! -d "$PROFILE_DIR" ]; then
            fail_msg "Profile '$PROFILE_NAME' not found at $PROFILE_DIR"
            exit 1
        fi
        return
    fi

    # Single profile (or only default) → use it silently
    if [ $count -le 1 ]; then
        PROFILE_DIR="$HOME/.claude"
        return
    fi

    # Multiple profiles → ask user
    echo ""
    printf "  ${BOLD}Multiple profiles detected:${RESET}\n"
    echo ""
    local i=1
    for entry in "${profiles[@]}"; do
        local name="${entry%%:*}"
        local path="${entry#*:}"
        local marker=""
        [ -f "${path}distill/.version" ] && marker=" ${DIM}(distill installed)${RESET}"
        printf "    ${CYAN}%d)${RESET} %s %s${marker}\n" "$i" "$name" "${DIM}($path)${RESET}"
        i=$((i + 1))
    done
    echo ""
    printf "  ${BOLD}Choose profile [1-%d]:${RESET} " "$count"
    read -r choice

    if [ -z "$choice" ] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ] 2>/dev/null; then
        fail_msg "Invalid choice. Run with --profile <name> to skip this prompt."
        exit 1
    fi

    local selected="${profiles[$((choice-1))]}"
    PROFILE_DIR="${selected#*:}"
    # Remove trailing slash
    PROFILE_DIR="${PROFILE_DIR%/}"
}

# ═══ MAIN INSTALLATION ═══

show_header

# Codex is opt-in. Keep the existing Claude installer path unchanged.
if [ "$TARGET" = "codex" ]; then
    install_codex
    exit 0
fi

# Resolve which profile to install to
resolve_profile

# Set paths based on resolved profile
CMD_DIR="$PROFILE_DIR/commands"
DISTILL_DIR="$PROFILE_DIR/distill"
RULES_DIR="$PROFILE_DIR/rules"
CLAUDE_MD="$PROFILE_DIR/CLAUDE.md"

info_msg "Installing to: ${PROFILE_DIR}"
echo ""

# Detect existing installation
EXISTING_VERSION=""
if [ -f "$DISTILL_DIR/.version" ]; then
    EXISTING_VERSION=$(cat "$DISTILL_DIR/.version")
    info_msg "Existing installation: v${EXISTING_VERSION} → v${VERSION}"
    echo ""
fi


show_section "Core files"

# Ensure directories exist
mkdir -p "$CMD_DIR"
mkdir -p "$DISTILL_DIR"/{craft,ops,profile,projects,feedback,archive}

# Download core files and resolve {DISTILL_DIR} to actual path

curl -sL "$REPO/distill.md" | sed "s|{DISTILL_DIR}|$DISTILL_DIR|g" > "$CMD_DIR/distill.md"
done_msg "distill.md ${DIM}(command)${RESET}"


curl -sL "$REPO/distill-process.md" | sed "s|{DISTILL_DIR}|$DISTILL_DIR|g" > "$DISTILL_DIR/distill-process.md"
done_msg "distill-process.md ${DIM}(process engine)${RESET}"


curl -sL "$REPO/distill-monitor.md" | sed "s|{DISTILL_DIR}|$DISTILL_DIR|g" > "$DISTILL_DIR/distill-monitor.md"
done_msg "distill-monitor.md ${DIM}(session monitor)${RESET}"

# Version
echo "$VERSION" > "$DISTILL_DIR/.version"

# Spine
if [ ! -f "$DISTILL_DIR/SPINE.md" ]; then
    echo "# Distill Knowledge Index" > "$DISTILL_DIR/SPINE.md"
    echo "" >> "$DISTILL_DIR/SPINE.md"
    echo "<!-- This file is managed by aura-distill. Max 80 lines. -->" >> "$DISTILL_DIR/SPINE.md"
    echo "<!-- Each entry: - [Title](path.md) — when to read this -->" >> "$DISTILL_DIR/SPINE.md"
    done_msg "SPINE.md ${DIM}(knowledge index)${RESET}"
else
    skip_msg "SPINE.md ${DIM}(preserved)${RESET}"
fi

# ═══ KNOWLEDGE RETRIEVAL (rules file) ═══

show_section "Knowledge retrieval"

mkdir -p "$RULES_DIR"
curl -sL "$REPO/rules/distill.md" | sed "s|{DISTILL_DIR}|$DISTILL_DIR|g" > "$RULES_DIR/distill.md"
done_msg "rules/distill.md ${DIM}(auto-loads every session)${RESET}"

# ═══ CLAUDE.md INTEGRATION ═══

show_section "Session integration"

# Disable auto-memory (distill owns knowledge management)
SETTINGS_JSON="$PROFILE_DIR/settings.json"
if [ -f "$SETTINGS_JSON" ]; then
    if grep -q '"autoMemoryEnabled"' "$SETTINGS_JSON" 2>/dev/null; then
        skip_msg "Auto-memory already configured in settings.json"
    else
        # Add autoMemoryEnabled: false after the opening brace
        sed -i.bak 's/^{$/{\n  "autoMemoryEnabled": false,/' "$SETTINGS_JSON"
        rm -f "$SETTINGS_JSON.bak"
        done_msg "Disabled auto-memory ${DIM}(distill owns knowledge)${RESET}"
    fi
else
    echo '{ "autoMemoryEnabled": false }' > "$SETTINGS_JSON"
    done_msg "Created settings.json with auto-memory disabled"
fi

if [ -f "$CLAUDE_MD" ]; then
    if grep -q "aura-distill" "$CLAUDE_MD" 2>/dev/null; then
        done_msg "CLAUDE.md ${DIM}(already configured)${RESET}"
    elif grep -q "distill" "$CLAUDE_MD" 2>/dev/null; then
        # Older version reference — replace it
        sed -i.bak '/distill/d' "$CLAUDE_MD"
        rm -f "$CLAUDE_MD.bak"
        echo "" >> "$CLAUDE_MD"
        echo "$DISTILL_LINE" >> "$CLAUDE_MD"
        done_msg "CLAUDE.md ${DIM}(upgraded)${RESET}"
    else
        echo "" >> "$CLAUDE_MD"
        echo "$DISTILL_LINE" >> "$CLAUDE_MD"
        done_msg "CLAUDE.md configured"
    fi
else
    echo "$DISTILL_LINE" > "$CLAUDE_MD"
    done_msg "Created CLAUDE.md"
fi

# ═══ MEMORY MIGRATION CHECK ═══

# Detect existing memory files that should be ingested
MEMORY_FILES=$(find "$HOME/.claude" -path "*/memory/*.md" -not -path "*/distill/*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$MEMORY_FILES" -gt 0 ] && [ ! -f "$DISTILL_DIR/.migrated" ]; then
    echo ""
    printf "  ${CYAN}━━${RESET} ${BOLD}Existing memories detected${RESET}\n"
    echo ""
    printf "  Found ${BOLD}${MEMORY_FILES}${RESET} memory files from Claude's built-in system.\n"
    printf "  Since distill now owns knowledge management, these won't be\n"
    printf "  read by the auto-memory system anymore.\n"
    echo ""
    printf "  ${BOLD}On your next session, run ${CYAN}/distill${RESET}${BOLD} — it will:${RESET}\n"
    printf "    • Read your existing memories\n"
    printf "    • Ingest them into distill's tiered system\n"
    printf "    • Apply quality checks and proper categorization\n"
    printf "    • Your old files stay untouched (as backup)\n"
    echo ""
    # Flag so we only show this once
    echo "pending $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DISTILL_DIR/.needs-migration"
fi

# ═══ COMPLETE ═══

echo ""
echo ""
printf "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
echo ""
printf "  ${GREEN}${BOLD}Installed${RESET}\n"
printf "  ${DIM}Zero dependencies. Just files.${RESET}\n"
echo ""
printf "  ${DIM}Version:  ${RESET}v${VERSION}\n"
printf "  ${DIM}Command:  ${RESET}/distill\n"
printf "  ${DIM}Knowledge:${RESET} ~/.claude/distill/\n"
echo ""
if [ -n "$EXISTING_VERSION" ]; then
    printf "  ${CYAN}Upgraded${RESET} v${EXISTING_VERSION} → v${VERSION}\n"
    echo ""
fi
printf "  ${DIM}Uninstall (keeps your learnings):${RESET}\n"
printf "    ${DIM}rm -rf ~/.claude/distill ~/.claude/commands/distill.md ~/.claude/rules/distill.md${RESET}\n"
echo ""
printf "  ${PURPLE}say what matters. it's listening.${RESET}\n"
echo ""
printf "  ${DIM}Research:${RESET} https://tomacco.github.io/aura-distill/research/\n"
printf "  ${DIM}@tomacco is super happy to share this research with you.${RESET}\n"
printf "  ${DIM}Every finding is reproducible. Raw outputs published.${RESET}\n"
echo ""
