#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-launch.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(cplug_cmake_launch_test C)
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
  "+lua package.loaded['dap'] = { run = function(cfg) vim.g.cplug_cmake_launch = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ launch = { on_missing = 'always' } }); local result, err = require('cplug').compile_and_debug(); assert(result, err); assert(result.backend == 'cmake'); assert(vim.fn.filereadable('build/hello') == 1); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(vim.g.cplug_cmake_launch.program == (vim.fn.getcwd() .. '/build/hello'):gsub('^/tmp/', '/private/tmp/')); assert(not vim.g.cplug_cmake_launch.program:find('/CMakeFiles/', 1, true))" \
  +qall

echo "cmake launch generation test passed"
