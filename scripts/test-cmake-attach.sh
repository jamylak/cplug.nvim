#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}

TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-attach.XXXXXX")
TEST_DIR_REAL=$(cd "$TEST_DIR" && pwd)

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(cplug_attach_test LANGUAGES CXX)

add_executable(cplug-attach main.cpp)
set_target_properties(cplug-attach PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
EOF

cat > "$TEST_DIR/main.cpp" <<'EOF'
#include <iostream>

int main() {
  std::cout << "hello" << std::endl;
  return 0;
}
EOF

echo "==> cmake attach skips build and generates a process-attach config"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+cd $TEST_DIR_REAL" \
  "+lua local ok, err = pcall(function() local original_system = vim.system; vim.system = function() error('vim.system should not be called during attach') end; package.loaded['dap'] = { run = function(cfg) vim.g.cplug_cmake_attach = cfg end, ABORT = {} }; package.loaded['cplug.process_picker'] = { pick_process = function() return 4242 end }; package.loaded['dapui'] = { open = function() end, setup = function() end, close = function() end }; package.loaded['dap-disasm'] = { setup = function() end }; require('cplug').setup({ launch = { on_missing = 'always' } }); local result, attach_err = require('cplug').attach(); vim.system = original_system; assert(result, attach_err); assert(result.backend == 'cmake'); assert(result.dap.low_level == true); assert(result.dap.layout == 'native'); assert(vim.g.cplug_cmake_attach.request == 'attach'); assert(type(vim.g.cplug_cmake_attach.pid) == 'function'); assert(vim.g.cplug_cmake_attach.pid() == 4242); assert(vim.fn.filereadable('.vscode/launch.json') == 1); local launch = vim.json.decode(table.concat(vim.fn.readfile('.vscode/launch.json'), '\n')); assert(#launch.configurations == 1); assert(launch.configurations[1].request == 'attach'); assert(launch.configurations[1].pid == '\${command:pickProcess}') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake attach test passed"
