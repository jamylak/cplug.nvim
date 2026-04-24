#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-python-debugpy.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/app.py" <<'EOF'
print("hello")
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() local original_exepath = vim.fn.exepath; local original_system = vim.system; local calls = {}; vim.fn.exepath = function(bin) if bin == 'uv' then return '/fake/uv' end if bin == 'python3' then return '/fake/python3' end return original_exepath(bin) end; vim.system = function(args, opts) table.insert(calls, args); return { wait = function() if args[1] == '/fake/python3' or tostring(args[1]):find('/%.venv/bin/python$') then return { code = vim.fn.filereadable('.debugpy-installed') == 1 and 0 or 1, stdout = '', stderr = '' } end if args[1] == 'uv' and args[2] == '--native-tls' and args[3] == 'venv' then vim.fn.mkdir('.venv/bin', 'p'); vim.fn.writefile({ '#!/bin/sh', 'exit 0' }, '.venv/bin/python'); vim.fn.system({ 'chmod', '+x', '.venv/bin/python' }); return { code = 0, stdout = '', stderr = '' } end if args[1] == 'uv' and args[2] == '--native-tls' and args[3] == 'pip' then vim.fn.writefile({ 'ok' }, '.debugpy-installed'); return { code = 0, stdout = '', stderr = '' } end error('unexpected command: ' .. vim.inspect(args)) end } end; package.loaded['dap'] = { adapters = {}, run = function(cfg) vim.g.cplug_python_bootstrap = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ python = { uv = { native_tls = true } } }); local result, run_err = require('cplug').compile_and_debug(); vim.fn.exepath = original_exepath; vim.system = original_system; assert(result, run_err); assert(result.backend == 'python'); assert(result.build.debugpy.bootstrapped == true); assert(vim.fn.filereadable('.venv/bin/python') == 1); assert(vim.g.cplug_python_bootstrap.python == (vim.fn.getcwd() .. '/.venv/bin/python'):gsub('^/tmp/', '/private/tmp/')); assert(type(package.loaded['dap'].adapters.python) == 'table'); assert(package.loaded['dap'].adapters.python.command == vim.g.cplug_python_bootstrap.python); assert(calls[1][1] == 'uv' and calls[1][2] == '--native-tls' and calls[1][3] == 'venv'); assert(calls[2][1] == 'uv' and calls[2][2] == '--native-tls' and calls[2][3] == 'pip') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "python debugpy bootstrap test passed"
