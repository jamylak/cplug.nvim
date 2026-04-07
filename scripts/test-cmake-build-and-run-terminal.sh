#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-build-run.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/main.c" <<'EOF'
#include <stdio.h>

int main(void) {
  puts("hello-build-run-term");
  return 0;
}
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() require('cplug').setup({ scaffold = { on_missing = 'always' } }); local result, build_err = require('cplug').cmake_build_and_run(); assert(result, build_err); assert(result.build and result.build.job_id, 'expected build terminal job metadata'); local build_wait = vim.fn.jobwait({ result.build.job_id }, 20000); assert(build_wait[1] == 0, 'expected successful build job exit'); vim.wait(5000, function() return result.run and result.run.job_id ~= nil end, 50); assert(result.run and result.run.job_id, 'expected run terminal job metadata after successful build'); local run_wait = vim.fn.jobwait({ result.run.job_id }, 20000); assert(run_wait[1] == 0, 'expected successful run job exit'); local lines = vim.api.nvim_buf_get_lines(result.run.terminal_buf, 0, -1, false); assert(table.concat(lines, '\n'):find('hello%-build%-run%-term') ~= nil, 'expected run terminal output'); vim.wait(2000, function() return not vim.api.nvim_buf_is_valid(result.build.terminal_buf) end, 50); assert(not vim.api.nvim_buf_is_valid(result.build.terminal_buf), 'expected build terminal buffer to auto-close') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake build-and-run terminal test passed"
