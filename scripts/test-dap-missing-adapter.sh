#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-dap-missing-adapter.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(cplug_missing_adapter_test C)
add_executable(hello main.c)
EOF

cat > "$TEST_DIR/main.c" <<'EOF'
#include <stdio.h>

int main(void) {
  puts("hello");
  return 0;
}
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() local old_notify = vim.notify; vim.notify = function() end; package.loaded['dap'] = { adapters = {}, run = function() error('dap.run should not be called without an adapter') end }; package.loaded['dapui'] = { open = function() error('dapui.open should not be called before adapter validation') end }; require('cplug').setup({ launch = { on_missing = 'always' } }); local result, run_err = require('cplug').compile_and_debug(); vim.notify = old_notify; assert(result == nil); assert(type(run_err) == 'string' and run_err:find('Config references missing adapter', 1, true), run_err) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "dap missing adapter test passed"
