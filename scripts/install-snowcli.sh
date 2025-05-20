#!/usr/bin/bash

set -euo pipefail
PIPX_PATH="snow_pipx_path"
PYTHON_PATH=$(python -c "import sys; print(sys.executable)")

# These commands ensure that each time `snow` command is executed the system will use 
# the executable in the pipx installation folder and not in any other installation folder.

export PIPX_BIN_DIR=${PIPX_BIN_DIR:-"${HOME}/.local/bin"}/$PIPX_PATH

mkdir -p "${PIPX_BIN_DIR}"

pip install git+https://github.com/snowflakedb/snowflake-cli.git@release-v3.8.1 --verbose

# if [ "$CLI_VERSION" == "latest" ]; then
#     pipx install snowflake-cli --python "$PYTHON_PATH"
# else 
#     pipx install snowflake-cli=="$CLI_VERSION" --python "$PYTHON_PATH"
# fi


echo "$PIPX_BIN_DIR" >> "$GITHUB_PATH"
