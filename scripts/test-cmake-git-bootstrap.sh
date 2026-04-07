#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-cmake-git.XXXXXX")

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

cat > "$TEST_DIR/main.c" <<'EOF'
#include <stdio.h>

int main(void) {
  puts("hello-git-bootstrap");
  return 0;
}
EOF

nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() package.loaded['dap'] = { run = function(cfg) vim.g.cplug_git_bootstrap = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ launch = { on_missing = 'always' }, c_family = { bootstrap_git = true } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'cmake'); assert(vim.fn.isdirectory('.git') == 1, 'expected git repository'); assert(vim.fn.filereadable('.gitignore') == 1, 'expected .gitignore'); local gitignore = table.concat(vim.fn.readfile('.gitignore'), '\n'); assert(gitignore:find('build/', 1, true) ~= nil, 'expected build/ in .gitignore'); assert(vim.g.cplug_git_bootstrap.program:find('/build/', 1, true) ~= nil) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "cmake git bootstrap test passed"
