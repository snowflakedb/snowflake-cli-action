#!/usr/bin/env bash

# Install the Snowflake CLI.
#
# The network path matches the historical action steps (uv tool install, with
# the interpreter selected by astral-sh/setup-uv). The offline paths do not
# contact PyPI or GitHub:
#   - snow already on PATH and no version, ref, or artifact: no-op
#   - CLI_ARTIFACT: uv tool install --offline using the python3 on PATH
#
# Env:
#   CLI_VERSION         Version, "latest", or empty (empty means latest).
#   CUSTOM_GITHUB_REF   Install from a git ref instead of PyPI.
#   CLI_ARTIFACT        Local wheel, sdist, or directory of wheels.

set -euo pipefail

CLI_VERSION="${CLI_VERSION:-}"
CUSTOM_GITHUB_REF="${CUSTOM_GITHUB_REF:-}"
CLI_ARTIFACT="${CLI_ARTIFACT:-}"

if [ -n "$CLI_VERSION" ] && [ -n "$CUSTOM_GITHUB_REF" ]; then
    echo "You cannot set BOTH cli-version and custom-github-ref"
    exit 1
fi
if [ -n "$CLI_ARTIFACT" ] && { [ -n "$CLI_VERSION" ] || [ -n "$CUSTOM_GITHUB_REF" ]; }; then
    echo "::error::cli-artifact cannot be combined with cli-version or custom-github-ref"
    exit 1
fi

export PATH="${HOME}/.local/bin:${PATH}"

publish_path() {
    if [ -z "${GITHUB_PATH:-}" ]; then
        return 0
    fi
    echo "${HOME}/.local/bin" >> "$GITHUB_PATH"
    if command -v snow >/dev/null 2>&1; then
        dirname "$(command -v snow)" >> "$GITHUB_PATH"
    fi
}

if [ -z "$CLI_VERSION" ] && [ -z "$CUSTOM_GITHUB_REF" ] && [ -z "$CLI_ARTIFACT" ] \
    && command -v snow >/dev/null 2>&1; then
    echo "Snowflake CLI already on PATH ($(command -v snow)); skipping download."
    snow --version
    publish_path
    exit 0
fi

if [ -n "$CLI_ARTIFACT" ]; then
    if [ ! -e "$CLI_ARTIFACT" ]; then
        echo "::error::cli-artifact path does not exist: ${CLI_ARTIFACT}"
        exit 1
    fi
    if ! command -v uv >/dev/null 2>&1; then
        echo "::error::cli-artifact is set but uv is not on PATH. Preinstall uv; this path does not download it."
        exit 1
    fi
    python="$(command -v python3 || true)"
    if [ -z "$python" ]; then
        echo "::error::cli-artifact is set but python3 is not on PATH. Preinstall Python; this path does not download an interpreter."
        exit 1
    fi
    echo "Installing Snowflake CLI from local artifact ${CLI_ARTIFACT} (offline)"
    if [ -d "$CLI_ARTIFACT" ]; then
        uv tool install --offline --python "$python" --find-links "$CLI_ARTIFACT" snowflake-cli
    else
        links="$(cd "$(dirname "$CLI_ARTIFACT")" && pwd)"
        uv tool install --offline --python "$python" --find-links "$links" "$CLI_ARTIFACT"
    fi
elif [ -n "$CLI_VERSION" ] && [ "$CLI_VERSION" != "latest" ] && [ -z "$CUSTOM_GITHUB_REF" ]; then
    uv tool install "snowflake-cli==${CLI_VERSION}"
elif [ -z "$CLI_VERSION" ] && [ -n "$CUSTOM_GITHUB_REF" ]; then
    uv tool install "git+https://github.com/snowflakedb/snowflake-cli.git@${CUSTOM_GITHUB_REF}"
else
    uv tool install snowflake-cli
fi

publish_path
export PATH="${HOME}/.local/bin:${PATH}"
snow --version
