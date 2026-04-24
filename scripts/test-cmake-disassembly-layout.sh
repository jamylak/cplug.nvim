#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}

TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-disasm.XXXXXX")
TEST_DIR_REAL=$(cd "$TEST_DIR" && pwd)

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(cplug_disasm_test LANGUAGES CXX)

add_executable(cplug-disasm main.cpp)
set_target_properties(cplug-disasm PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
EOF

cat > "$TEST_DIR/main.cpp" <<'EOF'
#include <iostream>

int main() {
  std::cout << "hello" << std::endl;
  return 0;
}
EOF

echo "==> default low-level layout includes disassembly when available"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+cd $TEST_DIR_REAL" \
  "+lua local ok, err = pcall(function() _G.cplug_disasm_open = {}; package.preload['dap'] = function() return { adapters = { lldb = {} }, run = function(cfg) vim.g.cplug_disasm_run = cfg end } end; package.preload['dapui'] = function() return { setup = function(cfg) vim.g.cplug_disasm_dapui_setup = cfg end, open = function(opts) table.insert(_G.cplug_disasm_open, opts) end, close = function() vim.g.cplug_disasm_closed = true end } end; package.preload['dap-disasm'] = function() return { setup = function(cfg) vim.g.cplug_disasm_setup = cfg end } end; require('cplug').setup({ launch = { on_missing = 'always' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(result.dap.low_level == true); assert(result.dap.disassembly == true); assert(result.dap.layout == 'native'); assert(vim.g.cplug_disasm_setup.dapview_register == false); assert(type(vim.g.cplug_disasm_dapui_setup.layouts) == 'table'); assert(vim.g.cplug_disasm_dapui_setup.layouts[1].elements[1].id == 'scopes'); assert(vim.g.cplug_disasm_dapui_setup.layouts[1].elements[2].id == 'breakpoints'); assert(vim.g.cplug_disasm_dapui_setup.layouts[1].elements[3].id == 'stacks'); assert(vim.g.cplug_disasm_dapui_setup.layouts[1].elements[4].id == 'watches'); assert(vim.g.cplug_disasm_dapui_setup.layouts[2].elements[1].id == 'disassembly'); assert(vim.g.cplug_disasm_dapui_setup.layouts[2].elements[2].id == 'repl'); assert(vim.g.cplug_disasm_dapui_setup.layouts[2].elements[3] == nil); assert(vim.g.cplug_disasm_dapui_setup.layouts[3] == nil); assert(#_G.cplug_disasm_open == 2); assert(_G.cplug_disasm_open[1].layout == 1); assert(_G.cplug_disasm_open[2].layout == 2); end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "==> disassembly pane can be disabled explicitly"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+cd $TEST_DIR_REAL" \
  "+lua local ok, err = pcall(function() _G.cplug_disasm_disabled_open = {}; package.preload['dap'] = function() return { adapters = { lldb = {} }, run = function(cfg) vim.g.cplug_disasm_disabled_run = cfg end } end; package.preload['dapui'] = function() return { setup = function(cfg) vim.g.cplug_disasm_disabled_dapui_setup = cfg end, open = function(opts) table.insert(_G.cplug_disasm_disabled_open, opts) end, close = function() vim.g.cplug_disasm_disabled_closed = true end } end; package.preload['dap-disasm'] = function() return { setup = function() vim.g.cplug_disasm_disabled_setup_called = true end } end; require('cplug').setup({ launch = { on_missing = 'always' }, dap = { disassembly = { enabled = false } } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(result.dap.low_level == true); assert(result.dap.disassembly == false); assert(result.dap.layout == 'native'); assert(vim.g.cplug_disasm_disabled_setup_called == nil); assert(type(vim.g.cplug_disasm_disabled_dapui_setup.layouts) == 'table'); assert(vim.g.cplug_disasm_disabled_dapui_setup.layouts[1].elements[1].id == 'scopes'); assert(vim.g.cplug_disasm_disabled_dapui_setup.layouts[1].elements[2].id == 'breakpoints'); assert(vim.g.cplug_disasm_disabled_dapui_setup.layouts[1].elements[3].id == 'stacks'); assert(vim.g.cplug_disasm_disabled_dapui_setup.layouts[1].elements[4].id == 'watches'); assert(vim.g.cplug_disasm_disabled_dapui_setup.layouts[2].elements[1].id == 'repl'); assert(vim.g.cplug_disasm_disabled_dapui_setup.layouts[2].elements[2] == nil); assert(vim.g.cplug_disasm_disabled_dapui_setup.layouts[3] == nil); assert(#_G.cplug_disasm_disabled_open == 2); assert(_G.cplug_disasm_disabled_open[1].layout == 1); assert(_G.cplug_disasm_disabled_open[2].layout == 2); end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "==> user-managed dapui layout skips cplug layout setup"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+cd $TEST_DIR_REAL" \
  "+lua local ok, err = pcall(function() vim.g.cplug_user_managed_open_count = 0; package.preload['dap'] = function() return { adapters = { lldb = {} }, run = function(cfg) vim.g.cplug_user_managed_run = cfg end } end; package.preload['dapui'] = function() return { setup = function(cfg) vim.g.cplug_user_managed_dapui_setup = cfg end, open = function(opts) vim.g.cplug_user_managed_open_count = vim.g.cplug_user_managed_open_count + 1; vim.g.cplug_user_managed_last_open = opts end, close = function() vim.g.cplug_user_managed_closed = true end, toggle = function() vim.g.cplug_user_managed_toggled = true end } end; package.preload['dap-disasm'] = function() return { setup = function(cfg) vim.g.cplug_user_managed_disasm_setup = cfg end } end; require('cplug').setup({ launch = { on_missing = 'always' }, dap = { manage_ui_layout = false, disassembly = { enabled = true } } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(result.dap.low_level == true); assert(result.dap.disassembly == true); assert(vim.g.cplug_user_managed_disasm_setup.dapview_register == false); assert(vim.g.cplug_user_managed_dapui_setup == nil); assert(vim.g.cplug_user_managed_open_count == 1); assert(vim.g.cplug_user_managed_last_open == nil); end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake disassembly layout test passed"
