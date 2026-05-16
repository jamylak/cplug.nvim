#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NVIM=${NVIM:-nvim}
TMP_BASE=${TMPDIR:-/tmp}
TEST_ROOT=$(mktemp -d "$TMP_BASE/cplug-fixture-projects.XXXXXX")

. "$ROOT_DIR/scripts/fixture-helpers.sh"

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT INT TERM

CPP_EMPTY_DIR=$(copy_fixture cpp-empty cplug-fixture-projects)
C_SOURCE_DIR=$(copy_fixture c-source-only cplug-fixture-projects)
CPP_EXISTING_DIR=$(copy_fixture cpp-existing-cmake cplug-fixture-projects)
CPP_AMBIG_DIR=$(copy_fixture cpp-source-only-ambiguous cplug-fixture-projects)
RUST_BIN_DIR=$(copy_fixture rust-bin cplug-fixture-projects)
RUST_LIB_DIR=$(copy_fixture rust-lib-only cplug-fixture-projects)
PY_SINGLE_DIR=$(copy_fixture python-single-file cplug-fixture-projects)
PY_PACKAGE_DIR=$(copy_fixture python-package-pyproject cplug-fixture-projects)
PY_VENV_DIR=$(copy_fixture python-existing-venv cplug-fixture-projects)
MIXED_DIR=$(copy_fixture mixed-cmake-python cplug-fixture-projects)
ATTACH_PY_DIR=$(copy_fixture attach-python-debugpy cplug-fixture-projects)
UNIT_LUA="$TEST_ROOT/fixture-projects.lua"

mkdir -p "$PY_VENV_DIR/.venv/bin"
ln -s /usr/bin/true "$PY_VENV_DIR/.venv/bin/python"

cat > "$UNIT_LUA" <<EOF
local backends = require("cplug.backends")
local cmake = require("cplug.backends.cmake")
local config = require("cplug.config")
local launch = require("cplug.launch")
local python = require("cplug.backends.python")
local rust = require("cplug.backends.rust")

local cpp_empty_dir = [[$CPP_EMPTY_DIR]]
local c_source_dir = [[$C_SOURCE_DIR]]
local cpp_existing_dir = [[$CPP_EXISTING_DIR]]
local cpp_ambig_dir = [[$CPP_AMBIG_DIR]]
local rust_bin_dir = [[$RUST_BIN_DIR]]
local rust_lib_dir = [[$RUST_LIB_DIR]]
local py_single_dir = [[$PY_SINGLE_DIR]]
local py_package_dir = [[$PY_PACKAGE_DIR]]
local py_venv_dir = [[$PY_VENV_DIR]]
local mixed_dir = [[$MIXED_DIR]]
local attach_py_dir = [[$ATTACH_PY_DIR]]

local function normalize(path)
  return vim.uv.fs_realpath(path) or path
end

local function make_ctx(cwd, opts)
  return {
    cwd = cwd,
    config = config.resolve(opts or {}),
  }
end

do
  local backend, project = backends.detect(make_ctx(cpp_empty_dir, {
    scaffold = { on_missing = "always" },
  }))
  assert(backend and backend.id == "cmake")
  assert(project.needs_scaffold == true)
  assert(project.empty_repo == true)
  local scaffolded, scaffold_err = cmake.scaffold(make_ctx(cpp_empty_dir, {
    scaffold = { on_missing = "always" },
  }), project)
  assert(scaffolded, scaffold_err)
  assert(vim.fn.filereadable(vim.fs.joinpath(cpp_empty_dir, "CMakeLists.txt")) == 1)
  assert(vim.fn.filereadable(vim.fs.joinpath(cpp_empty_dir, "src", "main.cpp")) == 1)
end

do
  local backend, project = backends.detect(make_ctx(c_source_dir, {
    scaffold = { on_missing = "always" },
  }))
  assert(backend and backend.id == "cmake")
  assert(project.needs_scaffold == true)
  assert(vim.deep_equal(project.languages, { "C" }))
  local scaffolded, scaffold_err = cmake.scaffold(make_ctx(c_source_dir, {
    scaffold = { on_missing = "always" },
  }), project)
  assert(scaffolded, scaffold_err)
  local cmake_lists = table.concat(vim.fn.readfile(vim.fs.joinpath(c_source_dir, "CMakeLists.txt")), "\n")
  assert(cmake_lists:find("main.c", 1, true) ~= nil)
  assert(cmake_lists:find("mathlib.c", 1, true) ~= nil)
  local generated = cmake.default_launch_config(make_ctx(c_source_dir), nil, {
    binaries = { vim.fs.joinpath(c_source_dir, "build", "c_source_only") },
  })
  assert(generated.configurations[1].request == "launch")
  assert(generated.configurations[1].type == "lldb")
  assert(generated.configurations[1].program == "\${workspaceFolder}/build/c_source_only")
end

do
  local backend, project = backends.detect(make_ctx(cpp_existing_dir))
  assert(backend and backend.id == "cmake")
  assert(project.needs_scaffold == nil)
  assert(vim.fn.filereadable(vim.fs.joinpath(cpp_existing_dir, "CMakeLists.txt")) == 1)
end

do
  local backend, project = backends.detect(make_ctx(cpp_ambig_dir, {
    scaffold = { on_missing = "always" },
  }))
  assert(backend and backend.id == "cmake")
  assert(project.needs_scaffold == true)
  assert(#project.sources == 3, "ambiguous fixture should keep all discovered sources for the documented pending case")
end

do
  local backend, project = backends.detect(make_ctx(rust_bin_dir))
  assert(backend and backend.id == "rust")
  assert(project.kind == "rust")
end

do
  local backend, project = backends.detect(make_ctx(rust_lib_dir))
  assert(backend and backend.id == "rust")
  assert(project.kind == "rust")
end

do
  local backend, project = backends.detect(make_ctx(py_single_dir, {
    python = { bootstrap_debugpy = false },
  }))
  assert(backend and backend.id == "python")
  local generated = python.default_launch_config(make_ctx(py_single_dir, {
    python = { bootstrap_debugpy = false },
  }), project, {
    interpreter = "/fake/python",
  })
  assert(generated.configurations[1].program == "\${workspaceFolder}/main.py")
  assert(generated.configurations[1].python == "/fake/python")
end

do
  local backend, project = backends.detect(make_ctx(py_package_dir, {
    python = { bootstrap_debugpy = false },
  }))
  assert(backend and backend.id == "python")
  local generated = python.default_launch_config(make_ctx(py_package_dir, {
    python = { bootstrap_debugpy = false },
  }), project, {
    interpreter = "/fake/python",
  })
  assert(generated.configurations[1].program == "\${file}")
end

do
  local backend, project = backends.detect(make_ctx(py_venv_dir, {
    python = { bootstrap_debugpy = false },
  }))
  assert(backend and backend.id == "python")
  local build_result, build_err = python.build(make_ctx(py_venv_dir, {
    python = { bootstrap_debugpy = false },
  }), project)
  assert(build_result, build_err)
  assert(
    normalize(build_result.interpreter) == normalize(vim.fs.joinpath(py_venv_dir, ".venv", "bin", "python"))
  )
  assert(build_result.debugpy.reason == "disabled")
end

do
  local backend = backends.detect(make_ctx(mixed_dir))
  assert(backend and backend.id == "cmake", "CMake backend must win over Python in mixed fixture")
end

do
  local ctx = make_ctx(attach_py_dir)
  local project = python.detect(ctx)
  local launch_data, launch_err = launch.write_generated(ctx, python, project, nil, {
    request_kind = "attach",
  })
  assert(launch_data, launch_err)
  assert(vim.fn.filereadable(vim.fs.joinpath(attach_py_dir, ".vscode", "launch.json")) == 1)
  local selected, select_err = launch.select(ctx, launch_data, {
    request_kind = "attach",
  })
  assert(selected, select_err)
  assert(selected.request == "attach")
  assert(selected.connect.host == "127.0.0.1")
  assert(selected.connect.port == 5678)
end
EOF

echo "==> fixture detection and non-interactive resolution"
"$NVIM" --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  "+lua local ok, err = pcall(function() dofile('$UNIT_LUA') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

if command -v cmake >/dev/null 2>&1 && { command -v c++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1 || command -v g++ >/dev/null 2>&1 || command -v cc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1; }; then
  EMPTY_BUILD_DIR=$(copy_fixture cpp-empty cplug-fixture-build)
  C_BUILD_DIR=$(copy_fixture c-source-only cplug-fixture-build)
  EXISTING_BUILD_DIR=$(copy_fixture cpp-existing-cmake cplug-fixture-build)

  echo "==> fixture C/C++ integration paths"
  "$NVIM" --headless -u NONE -i NONE \
    --cmd "set rtp+=$ROOT_DIR" \
    --cmd "cd $EMPTY_BUILD_DIR" \
    "+lua local ok, err = pcall(function() package.loaded['dap'] = { adapters = { lldb = {} }, run = function(cfg) vim.g.cplug_fixture_empty_launch = cfg end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup({ scaffold = { on_missing = 'always' }, launch = { on_missing = 'always', select = 'auto' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(vim.fn.filereadable('src/main.cpp') == 1); assert(vim.fn.filereadable('CMakeLists.txt') == 1); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(vim.fn.isdirectory('build') == 1) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
    +qall

  "$NVIM" --headless -u NONE -i NONE \
    --cmd "set rtp+=$ROOT_DIR" \
    --cmd "cd $C_BUILD_DIR" \
    "+lua local ok, err = pcall(function() package.loaded['dap'] = { adapters = { lldb = {} }, run = function(cfg) vim.g.cplug_fixture_c_launch = cfg end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup({ scaffold = { on_missing = 'always' }, launch = { on_missing = 'always', select = 'auto' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(vim.fn.filereadable('CMakeLists.txt') == 1); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(vim.g.cplug_fixture_c_launch.request == 'launch') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
    +qall

  "$NVIM" --headless -u NONE -i NONE \
    --cmd "set rtp+=$ROOT_DIR" \
    --cmd "cd $EXISTING_BUILD_DIR" \
    "+lua local ok, err = pcall(function() local before = table.concat(vim.fn.readfile('CMakeLists.txt'), '\n'); package.loaded['dap'] = { adapters = { lldb = {} }, run = function(cfg) vim.g.cplug_fixture_existing_launch = cfg end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup({ scaffold = { on_missing = 'always' }, launch = { on_missing = 'always', select = 'auto' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(vim.fn.filereadable('.vscode/launch.json') == 1); local after = table.concat(vim.fn.readfile('CMakeLists.txt'), '\n'); assert(before == after, 'existing CMakeLists.txt should not be scaffolded over') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
    +qall
else
  echo "==> skipping fixture C/C++ integration paths (cmake/compiler unavailable)"
fi

if command -v cargo >/dev/null 2>&1; then
  RUST_BIN_BUILD_DIR=$(copy_fixture rust-bin cplug-fixture-build)
  RUST_LIB_BUILD_DIR=$(copy_fixture rust-lib-only cplug-fixture-build)

  echo "==> fixture Rust integration paths"
  "$NVIM" --headless -u NONE -i NONE \
    --cmd "set rtp+=$ROOT_DIR" \
    --cmd "cd $RUST_BIN_BUILD_DIR" \
    "+lua local ok, err = pcall(function() package.loaded['dap'] = { adapters = { lldb = {} }, run = function(cfg) vim.g.cplug_fixture_rust_launch = cfg end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup({ launch = { on_missing = 'always', select = 'auto' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'rust'); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(vim.g.cplug_fixture_rust_launch.request == 'launch') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
    +qall

  "$NVIM" --headless -u NONE -i NONE \
    --cmd "set rtp+=$ROOT_DIR" \
    --cmd "cd $RUST_LIB_BUILD_DIR" \
    "+lua local ok, err = pcall(function() package.loaded['dap'] = { adapters = { lldb = {} }, run = function() error('dap should not run for lib-only rust fixture') end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup({ launch = { on_missing = 'always', select = 'auto' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result == nil); assert(run_err:find('No binary target was found in Cargo metadata', 1, true) ~= nil) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
    +qall
else
  echo "==> skipping fixture Rust integration paths (cargo unavailable)"
fi

if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
  PY_BUILD_DIR=$(copy_fixture python-single-file cplug-fixture-build)

  echo "==> fixture Python integration path"
  "$NVIM" --headless -u NONE -i NONE \
    --cmd "set rtp+=$ROOT_DIR" \
    --cmd "cd $PY_BUILD_DIR" \
    "+lua local ok, err = pcall(function() package.loaded['dap'] = { adapters = { python = {} }, run = function(cfg) vim.g.cplug_fixture_python_launch = cfg end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup({ launch = { on_missing = 'always', select = 'auto' }, python = { bootstrap_debugpy = false } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'python'); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(vim.g.cplug_fixture_python_launch.program:find('main.py', 1, true) ~= nil) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
    +qall
else
  echo "==> skipping fixture Python integration path (python unavailable)"
fi

echo "fixture project test passed"
