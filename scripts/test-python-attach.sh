#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}

TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-python-attach.XXXXXX")
TEST_DIR_REAL=$(cd "$TEST_DIR" && pwd)

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/app.py" <<'EOF'
print("hello from attach test")
EOF

mkdir -p "$TEST_DIR/.vscode"
cat > "$TEST_DIR/.vscode/launch.json" <<'EOF'
{"version":"0.2.0","configurations":[{"name":"Debug current file","type":"python","request":"launch","program":"${file}","console":"integratedTerminal"}]}
EOF

echo "==> python attach config generation merges into existing launch.json"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+cd $TEST_DIR_REAL" \
  "+lua local ok, err = pcall(function() require('cplug').setup({ launch = { configuration = 'Attach to Python server' } }); local result, gen_err = require('cplug').generate_attach_config(); assert(result, gen_err); local launch = vim.json.decode(table.concat(vim.fn.readfile('.vscode/launch.json'), '\n')); assert(#launch.configurations == 2); assert(launch.configurations[1].request == 'launch'); assert(launch.configurations[2].name == 'Attach to Python server'); assert(launch.configurations[2].request == 'attach'); assert(launch.configurations[2].connect.host == '127.0.0.1'); assert(launch.configurations[2].connect.port == 5678) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "==> python attach command runs selected attach config"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+cd $TEST_DIR_REAL" \
  "+lua local ok, err = pcall(function() package.loaded['dap'] = { run = function(cfg) vim.g.cplug_python_attach = cfg end }; package.loaded['dapui'] = { open = function() end, setup = function() end, close = function() end }; require('cplug').setup({ launch = { configuration = 'Attach to Python server' } }); local result, attach_err = require('cplug').attach(); assert(result, attach_err); assert(result.backend == 'python'); assert(result.dap.low_level == false); assert(vim.g.cplug_python_attach.request == 'attach'); assert(vim.g.cplug_python_attach.connect.host == '127.0.0.1'); assert(vim.g.cplug_python_attach.connect.port == 5678) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "python attach test passed"
