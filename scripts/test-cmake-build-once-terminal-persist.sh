#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-build-once-persist.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/main.c" <<'EOF'
#include <stdio.h>

int main(void) {
  puts("hello-build-persist");
  return 0;
}
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() require('cplug').setup({ scaffold = { on_missing = 'always' }, c_family = { keep_build_terminal_open = true } }); local result, build_err = require('cplug').cmake_build_once(); assert(result, build_err); assert(result.build and result.build.job_id, 'expected build terminal job metadata'); local wait_result = vim.fn.jobwait({ result.build.job_id }, 20000); assert(wait_result[1] == 0, 'expected successful build job exit'); vim.wait(500, function() return false end, 50); assert(vim.api.nvim_buf_is_valid(result.build.terminal_buf), 'expected build terminal buffer to stay open'); local binaries, binaries_err = require('cplug.backends.cmake').resolve_binaries({}, { build_dir = vim.fn.getcwd() .. '/build' }); assert(binaries, binaries_err); assert(binaries.binaries and binaries.binaries[1], 'expected built executable') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake build-once terminal persist test passed"
