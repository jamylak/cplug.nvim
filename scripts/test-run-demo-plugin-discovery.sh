#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_ROOT=$(mktemp -d "${TMP_BASE%/}/cplug-demo-discovery.XXXXXX")

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT INT TERM

HOME_DIR="$TEST_ROOT/home"
mkdir -p \
  "$HOME_DIR/.local/share/nvim/site/pack/core/opt/nvim-dap" \
  "$HOME_DIR/.local/share/nvim/site/pack/core/opt/nvim-dap-ui" \
  "$HOME_DIR/.local/share/nvim/site/pack/core/opt/nvim-dap-disasm" \
  "$HOME_DIR/.local/share/nvim/site/pack/core/opt/nvim-nio"

OUTPUT_FILE="$TEST_ROOT/output.txt"

HOME="$HOME_DIR" sh "$ROOT_DIR/scripts/run-cpp-demo.sh" toy -- --headless +qall >"$OUTPUT_FILE"

grep -F "nvim-dap: $HOME_DIR/.local/share/nvim/site/pack/core/opt/nvim-dap" "$OUTPUT_FILE" >/dev/null
grep -F "nvim-dap-ui: $HOME_DIR/.local/share/nvim/site/pack/core/opt/nvim-dap-ui" "$OUTPUT_FILE" >/dev/null
grep -F "nvim-dap-disasm: $HOME_DIR/.local/share/nvim/site/pack/core/opt/nvim-dap-disasm" "$OUTPUT_FILE" >/dev/null
grep -F "nvim-nio: $HOME_DIR/.local/share/nvim/site/pack/core/opt/nvim-nio" "$OUTPUT_FILE" >/dev/null

echo "run demo plugin discovery test passed"
