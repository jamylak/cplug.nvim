#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-python-layout.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

mkdir -p "$TEST_DIR/src/pkg" "$TEST_DIR/.venv/lib"

cat > "$TEST_DIR/pyproject.toml" <<'EOF'
[project]
name = "layout-test"
version = "0.1.0"
EOF

cat > "$TEST_DIR/src/pkg/app.py" <<'EOF'
print("nested")
EOF

cat > "$TEST_DIR/.venv/lib/ignored.py" <<'EOF'
print("ignored")
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() package.loaded['dap'] = { run = function(cfg) vim.g.cplug_python_layout = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ launch = { on_missing = 'always' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'python'); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(vim.g.cplug_python_layout.program == (vim.fn.getcwd() .. '/src/pkg/app.py'):gsub('^/tmp/', '/private/tmp/')); local launch = vim.fn.readfile('.vscode/launch.json'); assert(#launch == 1); assert(not launch[1]:find('ignored.py', 1, true)) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "nested python layout test passed"
