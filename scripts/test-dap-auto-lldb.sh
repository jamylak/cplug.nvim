#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-dap-auto-lldb.XXXXXX")
TEST_DIR_REAL=$(cd "$TEST_DIR" && pwd -P)

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(cplug_auto_lldb_test C)
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
  "+lua local ok, err = pcall(function() local original_exepath = vim.fn.exepath; vim.fn.exepath = function(bin) if bin == 'lldb-dap' then return '$TEST_DIR_REAL/fake-lldb-dap' end return '' end; package.loaded['dap'] = { adapters = {}, run = function(cfg) vim.g.cplug_auto_lldb_launch = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ launch = { on_missing = 'always' }, dap = { auto_adapter = 'lldb' } }); local result, run_err = require('cplug').compile_and_debug(); vim.fn.exepath = original_exepath; assert(result, run_err); assert(result.backend == 'cmake'); assert(type(package.loaded['dap'].adapters.lldb) == 'table'); assert(package.loaded['dap'].adapters.lldb.command == '$TEST_DIR_REAL/fake-lldb-dap'); assert(vim.g.cplug_auto_lldb_launch.program == (vim.fn.getcwd() .. '/build/hello'):gsub('^/tmp/', '/private/tmp/')) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "dap auto lldb test passed"
