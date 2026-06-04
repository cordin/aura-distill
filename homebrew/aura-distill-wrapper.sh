#!/bin/bash
# aura-distill - installed via Homebrew

set -e

LIBEXEC="${AURA_DISTILL_LIBEXEC:-__AURA_DISTILL_LIBEXEC__}"
LOCAL_REPO="file://$LIBEXEC"
export AURA_DISTILL_REPO="${AURA_DISTILL_REPO:-$LOCAL_REPO}"

usage() {
  cat <<'EOF'
Usage: aura-distill [install|uninstall|version] [--target claude|codex] [--profile <name>]

Commands:
  install    Install distill files to Claude Code or Codex (default)
  uninstall  Remove integration files (keeps your knowledge)
  version    Show installed version

Examples:
  aura-distill install
  aura-distill install --target codex
  aura-distill install --profile personal
  aura-distill uninstall --target codex
EOF
}

uninstall_claude() {
  local profile_name="$1"
  local profile="$HOME/.claude"

  if [ -n "$profile_name" ] && [ "$profile_name" != "default" ]; then
    profile="$HOME/.claude-$profile_name"
  fi

  rm -f "$profile/commands/distill.md"
  rm -f "$profile/rules/distill.md"
  rm -f "$profile/distill/distill-process.md"
  rm -f "$profile/distill/distill-monitor.md"
  rm -f "$profile/distill/.version"
  echo "Uninstalled from $profile (knowledge files preserved)"
}

uninstall() {
  local target="claude"
  local profile_name=""
  local remaining=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --target)
        target="$2"
        shift 2
        ;;
      --target=*)
        target="${1#*=}"
        shift
        ;;
      --profile)
        profile_name="$2"
        shift 2
        ;;
      --profile=*)
        profile_name="${1#*=}"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        remaining+=("$1")
        shift
        ;;
      *)
        if [ -z "$profile_name" ]; then
          profile_name="$1"
        else
          remaining+=("$1")
        fi
        shift
        ;;
    esac
  done

  case "$target" in
    claude)
      uninstall_claude "$profile_name"
      ;;
    codex)
      exec bash "$LIBEXEC/install.sh" --uninstall --target codex "${remaining[@]}"
      ;;
    *)
      echo "Unknown target '$target'. Expected claude or codex." >&2
      exit 1
      ;;
  esac
}

case "${1:-install}" in
  install)
    shift 2>/dev/null || true
    exec bash "$LIBEXEC/install.sh" "$@"
    ;;
  uninstall)
    shift 2>/dev/null || true
    uninstall "$@"
    ;;
  version)
    cat "$LIBEXEC/VERSION"
    ;;
  *)
    usage
    exit 1
    ;;
esac
