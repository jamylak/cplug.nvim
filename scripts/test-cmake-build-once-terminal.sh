#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=/tmp/cplug-cmake-build-once

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

cat >"$TMP_DIR/main.c" <<'EOF'
#include <stdio.h>

int main(void) {
  puts("hello-build-once");
  return 0;
}
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TMP_DIR" \
  "+lua local ok, err = pcall(function() require('cplug').setup({ scaffold = { on_missing = 'always' } }); local result, build_err = require('cplug').cmake_build_once(); assert(result, build_err); assert(result.build and result.build.job_id, 'expected build terminal job metadata'); assert(result.build.terminal_buf, 'expected build terminal buffer id'); assert(result.build.build_dir == (vim.fn.getcwd() .. '/build'):gsub('^/tmp/', '/private/tmp/'), 'expected configured build directory'); local wait_result = vim.fn.jobwait({ result.build.job_id }, 20000); assert(wait_result[1] == 0, 'expected successful build job exit'); vim.wait(2000, function() return not vim.api.nvim_buf_is_valid(result.build.terminal_buf) end, 50); assert(not vim.api.nvim_buf_is_valid(result.build.terminal_buf), 'expected build terminal buffer to auto-close'); local binaries, binaries_err = require('cplug.backends.cmake').resolve_binaries({}, { build_dir = vim.fn.getcwd() .. '/build' }); assert(binaries, binaries_err); assert(binaries.binaries and binaries.binaries[1], 'expected built executable') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake build-once terminal test passed"
