#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-python-interpreter.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

mkdir -p "$TEST_DIR/.venv/bin"

cat > "$TEST_DIR/app.py" <<'EOF'
print("hello")
EOF

ln -s /usr/bin/true "$TEST_DIR/.venv/bin/python"

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() package.loaded['dap'] = { adapters = { python = {} }, run = function(cfg) vim.g.cplug_python_default = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ launch = { on_missing = 'always' }, python = { bootstrap_debugpy = false } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'python'); assert(vim.g.cplug_python_default.python == (vim.fn.getcwd() .. '/.venv/bin/python'):gsub('^/tmp/', '/private/tmp/')); assert(vim.g.cplug_python_default.program == '\${workspaceFolder}/app.py'); assert(vim.g.cplug_python_default.console == 'internalConsole'); assert(vim.g.cplug_python_default.redirectOutput == true) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

rm -f "$TEST_DIR/.vscode/launch.json"

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() package.loaded['dap'] = { adapters = { python = {} }, run = function(cfg) vim.g.cplug_python_override = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ launch = { on_missing = 'always' }, python = { interpreter = '/custom/python' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'python'); assert(vim.g.cplug_python_override.python == '/custom/python') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "python interpreter resolution test passed"
