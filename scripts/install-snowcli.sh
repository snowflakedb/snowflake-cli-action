#!/usr/bin/bash

set -euo pipefail
PIPX_PATH="snow_pipx_path"
PYTHON_PATH=$(python -c "import sys; print(sys.executable)")

# These commands ensure that each time `snow` command is executed the system will use 
# the executable in the pipx installation folder and not in any other installation folder.

export PIPX_BIN_DIR=${PIPX_BIN_DIR:-"${HOME}/.local/bin"}/$PIPX_PATH

mkdir -p "${PIPX_BIN_DIR}"

# Validate that both CUSTOM_GITHUB_REF and CLI_VERSION are not set together
if [ -n "${CUSTOM_GITHUB_REF:-}" ] && [ -n "${CLI_VERSION:-}" ] ; then
    echo "Error: Both CUSTOM_GITHUB_REF and CLI_VERSION are set. Please provide only one (either a GitHub ref or a CLI version)." >&2
    exit 1
fi

if [ -n "${CUSTOM_GITHUB_REF:-}" ]; then
    pipx install \
        --python "$PYTHON_PATH" \
        --force \
        "git+https://github.com/snowflakedb/snowflake-cli.git@${CUSTOM_GITHUB_REF}"
elif [ -n "${CLI_VERSION:-}" ] && [ "${CLI_VERSION}" != "latest" ]; then
    pipx install snowflake-cli=="$CLI_VERSION" --python "$PYTHON_PATH"
else
    pipx install snowflake-cli --python "$PYTHON_PATH"
fi

echo "$PIPX_BIN_DIR" >> "$GITHUB_PATH"
