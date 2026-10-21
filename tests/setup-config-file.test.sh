#!/usr/bin/env bash
#
# Drive scripts/setup-config-file.sh the way the composite action does:
# a relative CONFIG_FILE_PATH with GITHUB_WORKSPACE set. Also assert a
# path outside the workspace is rejected. Isolated HOME so the runner's
# real ~/.snowflake is never touched.
#
# Usage: bash tests/setup-config-file.test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/setup-config-file.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: ${SCRIPT} not found"; exit 1; }

fail() { echo "FAIL: $1"; exit 1; }

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set (GitHub Actions provides it)}"

if ! command -v realpath >/dev/null 2>&1; then
  fail "realpath is not on PATH (required by scripts/setup-config-file.sh)"
fi
echo "realpath: $(command -v realpath)"
realpath --version 2>/dev/null || true
echo "GITHUB_WORKSPACE=$GITHUB_WORKSPACE"
if command -v cygpath >/dev/null 2>&1; then
  echo "cygpath -u GITHUB_WORKSPACE=$(cygpath -u "$GITHUB_WORKSPACE")"
fi

TEST_ROOT="$(mktemp -d)"
TEST_CONFIG="${GITHUB_WORKSPACE}/.ci-setup-config.toml"
trap 'rm -rf "$TEST_ROOT"; rm -f "$TEST_CONFIG"' EXIT
export HOME="${TEST_ROOT}/home"
mkdir -p "$HOME"

run_script() {
  local config_path="$1" rc=0
  (
    cd "$GITHUB_WORKSPACE"
    CONFIG_FILE_PATH="$config_path" bash "$SCRIPT"
  ) || rc=$?
  return "$rc"
}

# --- workspace-contained relative path (same shape as action.yml default) -----
printf 'default_connection_name = "ci"\n\n[connections.ci]\n' > "$TEST_CONFIG"
run_script "./.ci-setup-config.toml" \
  || fail "script failed for a relative config path inside GITHUB_WORKSPACE"
[ -f "$HOME/.snowflake/config.toml" ] && [ ! -L "$HOME/.snowflake/config.toml" ] \
  || fail "config was not staged as a regular file in ~/.snowflake"
grep -q 'default_connection_name = "ci"' "$HOME/.snowflake/config.toml" \
  || fail "staged config contents do not match the source"
echo "PASS: relative config path inside the workspace is staged via realpath"

# --- path outside the workspace is rejected -----------------------------------
OUTSIDE="$(mktemp "${TMPDIR:-/tmp}/outside-config.XXXXXX")"
printf 'must-not-be-copied\n' > "$OUTSIDE"
rm -f "$HOME/.snowflake/config.toml"
rc=0
run_script "$OUTSIDE" || rc=$?
[ "$rc" -ne 0 ] || fail "expected non-zero exit for a config path outside the workspace"
[ ! -e "$HOME/.snowflake/config.toml" ] \
  || fail "a config outside the workspace was staged"
echo "PASS: config outside the workspace is rejected"

echo "ALL PASS"
