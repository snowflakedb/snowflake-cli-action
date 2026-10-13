#!/usr/bin/env bash

# Decide whether this job must download uv or the Snowflake CLI.
#
# Writes skip_uv_setup and skip_install to $GITHUB_OUTPUT.
# See snowflakedb/snowflake-actions scripts/plan-snowflake-cli-install.sh.
# This legacy action keeps the same contract.

set -euo pipefail

CLI_VERSION="${CLI_VERSION:-}"
CUSTOM_GITHUB_REF="${CUSTOM_GITHUB_REF:-}"
CLI_ARTIFACT="${CLI_ARTIFACT:-}"

if [ -n "$CLI_VERSION" ] && [ -n "$CUSTOM_GITHUB_REF" ]; then
    echo "::error::You cannot set BOTH cli-version and custom-github-ref"
    exit 1
fi
if [ -n "$CLI_ARTIFACT" ] && { [ -n "$CLI_VERSION" ] || [ -n "$CUSTOM_GITHUB_REF" ]; }; then
    echo "::error::cli-artifact cannot be combined with cli-version or custom-github-ref"
    exit 1
fi

export PATH="${HOME}/.local/bin:${PATH}"

skip_install=false
skip_uv_setup=false

if [ -n "$CLI_ARTIFACT" ]; then
    skip_uv_setup=true
elif [ -z "$CLI_VERSION" ] && [ -z "$CUSTOM_GITHUB_REF" ] && command -v snow >/dev/null 2>&1; then
    skip_install=true
    skip_uv_setup=true
    echo "snow already on PATH ($(command -v snow)); skipping uv and Snowflake CLI downloads."
    # The install step is skipped, so publish snow's directory for later steps.
    if [ -n "${GITHUB_PATH:-}" ]; then
        dirname "$(command -v snow)" >> "$GITHUB_PATH"
    fi
fi

{
    echo "skip_install=${skip_install}"
    echo "skip_uv_setup=${skip_uv_setup}"
} >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
