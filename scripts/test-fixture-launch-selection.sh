#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NVIM=${NVIM:-nvim}
TMP_BASE=${TMPDIR:-/tmp}
TEST_ROOT=$(mktemp -d "$TMP_BASE/cplug-fixture-launch.XXXXXX")

. "$ROOT_DIR/scripts/fixture-helpers.sh"

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT INT TERM

EXISTING_DIR=$(copy_fixture cpp-existing-vscode-launch cplug-fixture-launch)
CPP_MULTI_DIR=$(copy_fixture cpp-multi-launch cplug-fixture-launch)
PY_MULTI_DIR=$(copy_fixture python-multi-launch cplug-fixture-launch)
BROKEN_DIR=$(copy_fixture cpp-broken-vscode-launch cplug-fixture-launch)
LUA_SCRIPT="$TEST_ROOT/fixture-launch-selection.lua"

cat > "$LUA_SCRIPT" <<EOF
local config = require("cplug.config")
local launch = require("cplug.launch")

local existing_dir = [[$EXISTING_DIR]]
local cpp_multi_dir = [[$CPP_MULTI_DIR]]
local py_multi_dir = [[$PY_MULTI_DIR]]
local broken_dir = [[$BROKEN_DIR]]

local function make_ctx(cwd, launch_opts)
  return {
    cwd = cwd,
    config = config.resolve({
      launch = vim.tbl_extend("force", {
        on_missing = "never",
        select = "auto",
      }, launch_opts or {}),
    }),
  }
end

do
  local ctx = make_ctx(existing_dir)
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  local before = table.concat(vim.fn.readfile(vim.fs.joinpath(existing_dir, ".vscode", "launch.json")), "\n")
  local selected, select_err = launch.select(ctx, launch_data)
  assert(selected, select_err)
  assert(selected.name == "Debug fixture app")
  local after = table.concat(vim.fn.readfile(vim.fs.joinpath(existing_dir, ".vscode", "launch.json")), "\n")
  assert(before == after, "existing launch.json should not be rewritten")
end

do
  local ctx = make_ctx(cpp_multi_dir, { select = "first" })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  local selected, select_err = launch.select(ctx, launch_data)
  assert(selected, select_err)
  assert(selected.name == "Debug app")
end

do
  local picker_calls = 0
  launch.set_picker(function(opts)
    picker_calls = picker_calls + 1
    assert(#opts.entries == 2, "launch auto picker should only receive compatible launch configs")
    assert(opts.entries[1].name == "Debug app")
    assert(opts.entries[2].name == "Debug tests")
    return opts.entries[2]
  end)

  local ctx = make_ctx(cpp_multi_dir, { select = "auto" })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  local selected, select_err = launch.select(ctx, launch_data)
  launch.set_picker(nil)
  assert(selected, select_err)
  assert(picker_calls == 1, "mock picker should be used once")
  assert(selected.name == "Debug tests")
end

do
  launch.set_picker(function()
    error("picker should not run for an explicit configuration name")
  end)
  local ctx = make_ctx(cpp_multi_dir, {
    configuration = "Debug tests",
    select = "auto",
  })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  local selected, select_err = launch.select(ctx, launch_data)
  launch.set_picker(nil)
  assert(selected, select_err)
  assert(selected.name == "Debug tests")
end

do
  local ctx = make_ctx(cpp_multi_dir, {
    configuration = "Attach running process",
  })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  local selected, select_err = launch.select(ctx, launch_data)
  assert(selected == nil)
  assert(select_err:find("not a launch configuration", 1, true) ~= nil)
end

do
  launch.set_picker(function()
    error("picker should not run when only one attach configuration matches")
  end)
  local ctx = make_ctx(cpp_multi_dir, { select = "auto" })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  local selected, select_err = launch.select(ctx, launch_data, {
    request_kind = "attach",
  })
  launch.set_picker(nil)
  assert(selected, select_err)
  assert(selected.name == "Attach running process")
  assert(selected.request == "attach")
end

do
  local ctx = make_ctx(py_multi_dir, { select = "picker" })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  launch.set_picker(function(opts)
    assert(#opts.entries == 2, "attach configs must be excluded from debug picker")
    assert(opts.entries[1].name == "Debug app")
    assert(opts.entries[2].name == "Debug current file")
    return opts.entries[1]
  end)
  local selected, select_err = launch.select(ctx, launch_data)
  launch.set_picker(nil)
  assert(selected, select_err)
  assert(selected.name == "Debug app")
end

do
  local ctx = make_ctx(py_multi_dir, {
    configuration = "Attach debugpy",
  })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  local selected, select_err = launch.select(ctx, launch_data)
  assert(selected == nil)
  assert(select_err:find("not a launch configuration", 1, true) ~= nil)
end

do
  local ctx = make_ctx(py_multi_dir, {
    configuration = "Debug app",
  })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  local selected, select_err = launch.select(ctx, launch_data, {
    request_kind = "attach",
  })
  assert(selected == nil, "expected explicit launch config to be rejected for attach mode")
  assert(type(select_err) == "string" and select_err:find("not an attach configuration", 1, true) ~= nil, select_err)
end

do
  local ctx = make_ctx(py_multi_dir, { select = "auto" })
  local launch_data, read_err = launch.read(ctx)
  assert(launch_data, read_err)
  launch.set_picker(function()
    error("attach selection should not invoke picker when there is exactly one attach config")
  end)
  local selected, select_err = launch.select(ctx, launch_data, {
    request_kind = "attach",
  })
  launch.set_picker(nil)
  assert(selected, select_err)
  assert(selected.name == "Attach debugpy")
  assert(selected.connect.host == "127.0.0.1")
  assert(selected.connect.port == 5678)
end

do
  local ctx = make_ctx(broken_dir)
  local resolved, resolve_err = launch.resolve(ctx, { id = "cmake" }, {}, nil)
  assert(resolved == nil)
  assert(type(resolve_err) == "string" and resolve_err:find("Failed to parse", 1, true) ~= nil, resolve_err)
end
EOF

echo "==> fixture launch selection and filtering"
"$NVIM" --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  "+lua local ok, err = pcall(function() dofile('$LUA_SCRIPT') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "fixture launch selection test passed"
