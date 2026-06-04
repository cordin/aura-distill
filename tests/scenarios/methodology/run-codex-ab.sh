#!/bin/bash
# Codex retrieval A/B runner
# Runs each retrieval scenario with and without the isolated aura-distill AGENTS block.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RETRIEVAL_DIR="$SCRIPT_DIR/../retrieval"
RESULTS_DIR="${CODEX_AB_RESULTS_DIR:-$SCRIPT_DIR/results/codex/$(date +%Y%m%d-%H%M%S)}"
REPEATS="${CODEX_AB_REPEATS:-3}"
CODEX_BIN="${CODEX_BIN:-codex}"
CODEX_TEST_MODEL="${CODEX_TEST_MODEL:-}"
CODEX_EXEC_API_KEY="${CODEX_API_KEY:-}"
CODEX_AUTH_FILE="${CODEX_AB_AUTH_FILE:-}"
CODEX_BYPASS_SANDBOX="${CODEX_AB_BYPASS_SANDBOX:-0}"

# Keep credentials out of installer, git, and filesystem setup subprocesses.
unset CODEX_API_KEY
unset CODEX_AB_AUTH_FILE

GREEN=$(printf '\033[0;32m')
CYAN=$(printf '\033[0;36m')
DIM=$(printf '\033[2m')
BOLD=$(printf '\033[1m')
RESET=$(printf '\033[0m')

TMP_ROOT=""

cleanup() {
    if [ -n "$TMP_ROOT" ]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

fail() {
    printf "Error: %s\n" "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  CODEX_API_KEY="..." CODEX_TEST_MODEL="..." ./run-codex-ab.sh [scenario]
  CODEX_AB_AUTH_FILE="$HOME/.codex/auth.json" CODEX_TEST_MODEL="..." ./run-codex-ab.sh [scenario]

Examples:
  CODEX_API_KEY="..." CODEX_TEST_MODEL="gpt-5.4" ./run-codex-ab.sh
  CODEX_API_KEY="..." CODEX_TEST_MODEL="gpt-5.4" ./run-codex-ab.sh 01-repeated-correction
  CODEX_AB_AUTH_FILE="$HOME/.codex/auth.json" CODEX_TEST_MODEL="gpt-5.4" ./run-codex-ab.sh 01-repeated-correction

Environment:
  CODEX_AB_REPEATS      Paired repetitions per scenario (default: 3)
  CODEX_AB_RESULTS_DIR  Override timestamped results directory
  CODEX_AB_AUTH_FILE    Copy a local auth.json into each disposable profile
  CODEX_AB_BYPASS_SANDBOX=1
                        Disable the Codex child sandbox for controlled local
                        fixtures when nested sandboxing is unavailable
  CODEX_BIN             Override the codex executable (used by tests)
EOF
}

strip_managed_agents_block() {
    local agents_md="$1"
    local stripped
    stripped=$(mktemp)

    awk '
        /<!-- aura-distill:codex:start -->/ { skipping = 1; next }
        /<!-- aura-distill:codex:end -->/ { skipping = 0; next }
        !skipping { print }
    ' "$agents_md" > "$stripped"

    mv "$stripped" "$agents_md"
}

rewrite_profile_paths() {
    local profile_home="$1"
    local old_home="$2"
    local new_home="$3"
    local file
    local rewritten

    while IFS= read -r file; do
        if grep -F -q "$old_home" "$file"; then
            rewritten=$(mktemp)
            awk -v old="$old_home" -v new="$new_home" '
                {
                    while ((pos = index($0, old)) > 0) {
                        $0 = substr($0, 1, pos - 1) new substr($0, pos + length(old))
                    }
                    print
                }
            ' "$file" > "$rewritten"
            mv "$rewritten" "$file"
        fi
    done < <(find "$profile_home" -type f ! -name auth.json -print)
}

seed_auth_file() {
    local codex_home="$1"

    if [ -n "$CODEX_AUTH_FILE" ]; then
        cp "$CODEX_AUTH_FILE" "$codex_home/auth.json"
        chmod 600 "$codex_home/auth.json"
    fi
}

prepare_scenario() {
    local scenario_dir="$1"
    local scenario_tmp="$2"
    local test_home="$scenario_tmp/home"
    local base_codex_home="$scenario_tmp/base-codex"
    local with_codex_home="$scenario_tmp/with-codex"
    local without_codex_home="$scenario_tmp/without-codex"
    local workspace="$scenario_tmp/workspace"

    mkdir -p "$test_home" "$base_codex_home" "$workspace"
    git -C "$workspace" init -q

    HOME="$test_home" \
    CODEX_HOME="$base_codex_home" \
    AURA_DISTILL_REPO="file://$REPO_DIR" \
        bash "$REPO_DIR/install.sh" --target codex >/dev/null

    cp -R "$scenario_dir/knowledge/." "$base_codex_home/distill/"
    cp -R "$base_codex_home" "$with_codex_home"
    cp -R "$base_codex_home" "$without_codex_home"
    rewrite_profile_paths "$with_codex_home" "$base_codex_home" "$with_codex_home"
    rewrite_profile_paths "$without_codex_home" "$base_codex_home" "$without_codex_home"
    strip_managed_agents_block "$without_codex_home/AGENTS.md"
    cat >> "$with_codex_home/AGENTS.md" <<EOF

## Controlled A/B evaluation guard

Before answering, read $with_codex_home/distill/SPINE.md and the matching Tier 2
files it references. If any required distill file cannot be read, reply exactly
\`DISTILL_RETRIEVAL_FAILED\` and stop.
EOF
    seed_auth_file "$with_codex_home"
    seed_auth_file "$without_codex_home"
}

run_condition() {
    local scenario_name="$1"
    local prompt="$2"
    local run_number="$3"
    local condition="$4"
    local scenario_tmp="$5"
    local codex_home
    local output_file="$RESULTS_DIR/${scenario_name}_run-${run_number}_${condition}.txt"
    local stderr_file="$RESULTS_DIR/${scenario_name}_run-${run_number}_${condition}.stderr.txt"
    local eval_prompt
    local codex_args=(
        exec
        --ephemeral
        --ignore-user-config
        --ignore-rules
        -c 'shell_environment_policy.inherit="none"'
        --model "$CODEX_TEST_MODEL"
        -C "$scenario_tmp/workspace"
    )

    eval_prompt=$(cat <<EOF
You are participating in a controlled response-quality evaluation. Answer the
user request directly as advice or proposed code. Do not inspect or modify the
workspace implementation. Follow loaded instructions, including reading any
referenced distill knowledge needed to answer accurately.

User request:
$prompt
EOF
)

    if [ "$CODEX_BYPASS_SANDBOX" = "1" ]; then
        codex_args+=(--dangerously-bypass-approvals-and-sandbox)
    else
        codex_args+=(--sandbox read-only)
    fi
    codex_args+=("$eval_prompt")

    case "$condition" in
        WITHOUT) codex_home="$scenario_tmp/without-codex" ;;
        WITH) codex_home="$scenario_tmp/with-codex" ;;
        *) fail "Unknown condition: $condition" ;;
    esac

    printf "    ${DIM}%s run %s...${RESET}\n" "$condition" "$run_number"

    if [ -n "$CODEX_EXEC_API_KEY" ]; then
        HOME="$scenario_tmp/home" \
        CODEX_HOME="$codex_home" \
        CODEX_API_KEY="$CODEX_EXEC_API_KEY" \
            "$CODEX_BIN" "${codex_args[@]}" > "$output_file" 2> "$stderr_file"
    else
        HOME="$scenario_tmp/home" \
        CODEX_HOME="$codex_home" \
            "$CODEX_BIN" "${codex_args[@]}" > "$output_file" 2> "$stderr_file"
    fi

    if grep -Eq 'DISTILL_RETRIEVAL_FAILED|bwrap: loopback: Failed RTM_NEWADDR' \
        "$output_file" "$stderr_file"; then
        fail "Codex retrieval failed for $scenario_name $condition run $run_number. If nested sandboxing is unavailable in a controlled local environment, retry with CODEX_AB_BYPASS_SANDBOX=1."
    fi
}

run_scenario() {
    local scenario_dir="$1"
    local scenario_name
    local scenario_tmp
    local prompt
    local run_number
    local order
    local condition

    scenario_name=$(basename "$scenario_dir")
    scenario_tmp="$TMP_ROOT/$scenario_name"
    prompt=$(cat "$scenario_dir/prompt.txt")

    printf "\n${BOLD}Scenario: %s${RESET}\n" "$scenario_name"
    mkdir -p "$scenario_tmp"
    prepare_scenario "$scenario_dir" "$scenario_tmp"
    cp "$scenario_dir/expected.md" "$RESULTS_DIR/${scenario_name}_expected.md"

    run_number=1
    while [ "$run_number" -le "$REPEATS" ]; do
        if [ $((run_number % 2)) -eq 1 ]; then
            order="WITHOUT WITH"
        else
            order="WITH WITHOUT"
        fi

        for condition in $order; do
            run_condition "$scenario_name" "$prompt" "$run_number" \
                "$condition" "$scenario_tmp"
        done

        run_number=$((run_number + 1))
    done

    printf "  ${GREEN}Captured %d paired repetitions${RESET}\n" "$REPEATS"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

case "$REPEATS" in
    ''|*[!0-9]*|0) fail "CODEX_AB_REPEATS must be a positive integer" ;;
esac
case "$CODEX_BYPASS_SANDBOX" in
    0|1) ;;
    *) fail "CODEX_AB_BYPASS_SANDBOX must be 0 or 1" ;;
esac

[ -n "$CODEX_TEST_MODEL" ] || fail "Set CODEX_TEST_MODEL to the explicit Codex model under test"
if [ -z "$CODEX_EXEC_API_KEY" ] && [ -z "$CODEX_AUTH_FILE" ]; then
    fail "Set CODEX_API_KEY or CODEX_AB_AUTH_FILE for codex exec authentication"
fi
if [ -n "$CODEX_AUTH_FILE" ] && [ ! -f "$CODEX_AUTH_FILE" ]; then
    fail "Codex auth file not found: $CODEX_AUTH_FILE"
fi
command -v "$CODEX_BIN" >/dev/null 2>&1 || fail "Codex executable not found: $CODEX_BIN"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/aura-distill-codex-ab.XXXXXX")
mkdir -p "$RESULTS_DIR"

cat > "$RESULTS_DIR/metadata.txt" <<EOF
runner=codex
model=$CODEX_TEST_MODEL
paired_repetitions=$REPEATS
conditions=WITHOUT,WITH
sandbox=$([ "$CODEX_BYPASS_SANDBOX" = "1" ] && printf bypassed || printf read-only)
started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

printf "\n${BOLD}Codex Distill Retrieval A/B Runner${RESET}\n"
printf "${DIM}Model: %s | paired repetitions: %s${RESET}\n" \
    "$CODEX_TEST_MODEL" "$REPEATS"

if [ -n "${1:-}" ]; then
    scenario_dir="$RETRIEVAL_DIR/$1"
    [ -f "$scenario_dir/prompt.txt" ] || fail "Unknown retrieval scenario: $1"
    [ -d "$scenario_dir/knowledge" ] || fail "Missing knowledge directory: $scenario_dir"
    [ -f "$scenario_dir/expected.md" ] || fail "Missing expected rubric: $scenario_dir"
    run_scenario "$scenario_dir"
else
    for scenario_dir in "$RETRIEVAL_DIR"/0[1-6]-*/; do
        [ -f "$scenario_dir/prompt.txt" ] || continue
        run_scenario "$scenario_dir"
    done
fi

printf "\n${CYAN}Results saved to:${RESET} %s\n" "$RESULTS_DIR"
printf "${DIM}Review each *_WITHOUT.txt / *_WITH.txt pair against its copied expected rubric.${RESET}\n\n"
