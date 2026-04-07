#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-empty-cpp.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() package.loaded['dap'] = { run = function(cfg) vim.g.cplug_cmake_empty_cpp = cfg end }; package.loaded['dapui'] = { open = function() end }; vim.fn.confirm = function() error('confirm should not be called') end; require('cplug').setup({ launch = { on_missing = 'always' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(vim.fn.filereadable('src/main.cpp') == 1); assert(vim.fn.filereadable('CMakeLists.txt') == 1); assert(vim.fn.filereadable('.clang-format') == 1); assert(vim.fn.filereadable('.vscode/launch.json') == 1); local source = table.concat(vim.fn.readfile('src/main.cpp'), '\n'); assert(source:find('std::cout', 1, true) ~= nil); assert(type(result.build.binaries) == 'table' and #result.build.binaries > 0); assert(vim.fn.filereadable(result.build.binaries[1]) == 1); assert(vim.g.cplug_cmake_empty_cpp.program == result.build.binaries[1]); assert(vim.g.cplug_cmake_empty_cpp.program:find('/build/', 1, true) ~= nil) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake empty C++ bootstrap test passed"
