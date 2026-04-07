#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
CPP_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-template-cpp.XXXXXX")
C_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-template-c.XXXXXX")

cleanup() {
  rm -rf "$CPP_DIR" "$C_DIR"
}

trap cleanup EXIT INT TERM

cat > "$CPP_DIR/main.cpp" <<'EOF'
int main() {
  return 0;
}
EOF

cat > "$C_DIR/main.c" <<'EOF'
int main(void) {
  return 0;
}
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  "+lua local ok, err = pcall(function() local backend = require('cplug.backends.cmake'); local config = require('cplug.config'); local function scaffold_project(dir, opts) vim.cmd('cd ' .. vim.fn.fnameescape(dir)); local resolved = config.resolve(vim.tbl_deep_extend('force', { c_family = { bootstrap_git = false } }, opts or {})); local ctx = { cwd = vim.fn.getcwd(), config = resolved }; local project = backend.detect(ctx); assert(project and project.needs_scaffold, 'expected scaffoldable project'); local scaffolded, scaffold_err = backend.scaffold(ctx, project); assert(scaffolded, scaffold_err); return table.concat(vim.fn.readfile('CMakeLists.txt'), '\n') end local cpp = scaffold_project('$CPP_DIR', {}); assert(cpp:find('set%(CMAKE_CXX_STANDARD 23%)')); assert(cpp:find('set%(CMAKE_CXX_EXTENSIONS OFF%)')); assert(cpp:find('option%(CPLUG_ENABLE_WARNINGS \"Enable strict warning flags\" ON%)')); assert(cpp:find('option%(CPLUG_WARNINGS_AS_ERRORS \"Treat warnings as errors\" OFF%)')); assert(cpp:find('option%(CPLUG_ENABLE_SANITIZERS \"Enable address/undefined sanitizers\" OFF%)')); assert(cpp:find('option%(CPLUG_ENABLE_FUZZING \"Build fuzz targets\" OFF%)')); assert(cpp:find('-Wformat=2', 1, true) ~= nil); assert(cpp:find('fuzz/fuzz_main.cpp', 1, true) ~= nil); local c = scaffold_project('$C_DIR', { c_family = { warnings_as_errors = true, bootstrap_git = false } }); assert(c:find('set%(CMAKE_C_STANDARD 17%)')); assert(c:find('set%(CMAKE_C_EXTENSIONS OFF%)')); assert(c:find('option%(CPLUG_WARNINGS_AS_ERRORS \"Treat warnings as errors\" ON%)')); assert(c:find('fuzz/fuzz_main.c', 1, true) ~= nil) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake template generation test passed"
