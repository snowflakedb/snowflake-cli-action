#!/usr/bin/env bash

set -euo pipefail

if [ ! -e "${CONFIG_FILE_PATH:-}" ]
then
    echo "Provided file ${CONFIG_FILE_PATH:-} not found, using default config file."
    exit 0
fi

# Copy through a temporary directory, then install into ~/.snowflake.
# When GITHUB_WORKSPACE is set, the source must be a regular file inside it.

# GitHub Actions sets GITHUB_WORKSPACE to a Windows path (D:\a\...) on
# windows-latest. Git Bash realpath of a relative file is POSIX (/d/a/...).
# Convert through cygpath so the prefix check compares one shape.
canonical_path() {
    local p="$1"
    if command -v cygpath >/dev/null 2>&1; then
        p="$(cygpath -u "$p")"
    fi
    realpath "$p"
}

if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    REAL_SRC="$(canonical_path "$CONFIG_FILE_PATH")"
    REAL_WS="$(canonical_path "$GITHUB_WORKSPACE")"
    case "$REAL_SRC" in
        "$REAL_WS"|"$REAL_WS"/*) ;;
        *)
            echo "Config file must be inside the workspace: $CONFIG_FILE_PATH"
            echo "resolved source: $REAL_SRC"
            echo "resolved workspace: $REAL_WS"
            exit 1
            ;;
    esac
    CONFIG_FILE_PATH="$REAL_SRC"
fi

if [ ! -f "$CONFIG_FILE_PATH" ] || [ -L "$CONFIG_FILE_PATH" ]; then
    echo "Config file must be a regular file: $CONFIG_FILE_PATH"
    exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
TEMP_CONFIG="${TEMP_DIR}/config.toml"

cp -- "$CONFIG_FILE_PATH" "$TEMP_CONFIG"

if [[ ! ${RUNNER_OS:-} = "Windows" ]]; then
    chmod 0600 "$TEMP_CONFIG"
fi

mkdir -p ~/.snowflake/
rm -f ~/.snowflake/config.toml
mv "$TEMP_CONFIG" ~/.snowflake/config.toml
