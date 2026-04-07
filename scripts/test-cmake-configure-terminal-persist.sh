#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-configure-persist.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/main.c" <<'EOF'
#include <stdio.h>

int main(void) {
  puts("hello-configure-persist");
  return 0;
}
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() require('cplug').setup({ scaffold = { on_missing = 'always' }, c_family = { keep_configure_terminal_open = true } }); local result, configure_err = require('cplug').cmake_configure(); assert(result, configure_err); assert(result.configure and result.configure.job_id, 'expected configure terminal job metadata'); local wait_result = vim.fn.jobwait({ result.configure.job_id }, 20000); assert(wait_result[1] == 0, 'expected successful configure job exit'); vim.wait(500, function() return false end, 50); assert(vim.api.nvim_buf_is_valid(result.configure.terminal_buf), 'expected configure terminal buffer to stay open'); assert(vim.fn.filereadable('build/CMakeCache.txt') == 1, 'expected CMakeCache.txt'); assert(vim.fn.filereadable('build/compile_commands.json') == 1, 'expected compile_commands.json') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake configure terminal persist test passed"
