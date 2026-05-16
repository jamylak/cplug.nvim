#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_ROOT=$(mktemp -d "${TMP_BASE%/}/cplug-demo-runner.XXXXXX")

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT INT TERM

FAKE_DAP_DIR=$TEST_ROOT/fake-nvim-dap
FAKE_DAPUI_DIR=$TEST_ROOT/fake-nvim-dap-ui
FAKE_NIO_DIR=$TEST_ROOT/fake-nvim-nio

mkdir -p "$FAKE_DAP_DIR/lua/dap/ui" "$FAKE_DAPUI_DIR/lua/dapui" "$FAKE_NIO_DIR/lua/nio"

cat > "$FAKE_DAP_DIR/lua/dap/init.lua" <<'EOF'
local M = {
  adapters = {},
  listeners = {
    after = {
      event_initialized = {},
      event_terminated = {},
      event_exited = {},
    },
    before = {
      attach = {},
      launch = {},
      event_terminated = {},
      event_exited = {},
    },
  },
}

function M.run(config)
  vim.g.cplug_demo_runner_config = config
end

function M.continue() end
function M.terminate() end
function M.step_over() end
function M.step_into() end
function M.step_out() end
function M.toggle_breakpoint() end
function M.run_to_cursor() end
function M.restart() end
function M.session()
  return nil
end

return M
EOF

cat > "$FAKE_DAP_DIR/lua/dap/ui/widgets.lua" <<'EOF'
return {
  hover = function() end,
}
EOF

cat > "$FAKE_DAPUI_DIR/lua/dapui/init.lua" <<'EOF'
local M = {}

function M.setup() end
function M.open() end
function M.close() end

return M
EOF

cat > "$FAKE_NIO_DIR/lua/nio/init.lua" <<'EOF'
return {}
EOF

echo "==> demo fixture runner uses resolved dap dependencies"
CPLUG_DEMO_FETCH=never \
CPLUG_DEMO_DAP_DIR="$FAKE_DAP_DIR" \
CPLUG_DEMO_DAPUI_DIR="$FAKE_DAPUI_DIR" \
CPLUG_DEMO_NIO_DIR="$FAKE_NIO_DIR" \
sh "$ROOT_DIR/scripts/demo/fixture.sh" cpp-existing-cmake -- \
  --headless \
  "+lua local ok, err = pcall(function() local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(vim.g.cplug_demo_runner_config ~= nil); end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "==> demo fixture runner keeps auto selection without Python bootstrap"
CPLUG_DEMO_FETCH=never \
CPLUG_DEMO_DAP_DIR="$FAKE_DAP_DIR" \
CPLUG_DEMO_DAPUI_DIR="$FAKE_DAPUI_DIR" \
CPLUG_DEMO_NIO_DIR="$FAKE_NIO_DIR" \
sh "$ROOT_DIR/scripts/demo/fixture.sh" python-multi-launch -- \
  --headless \
  "+lua local ok, err = pcall(function() local cfg = require('cplug').config(); assert(cfg.launch.select == 'auto'); assert(cfg.python.bootstrap_debugpy == false); local launch = require('cplug.launch'); launch.set_picker(function(opts) assert(#opts.entries == 2); return opts.entries[1] end); local original_system = vim.system; vim.system = function(args, opts) if args[2] == '-c' and args[3] == 'import debugpy' then return { wait = function() return { code = 1, stdout = '', stderr = '' } end } end error('unexpected bootstrap command: ' .. vim.inspect(args)) end; local result, run_err = require('cplug').compile_and_debug(); vim.system = original_system; launch.set_picker(nil); assert(result, run_err); assert(result.backend == 'python'); assert(vim.g.cplug_demo_runner_config.name == 'Debug app'); end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "demo fixture runner test passed"
