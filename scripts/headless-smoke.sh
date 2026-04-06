#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

echo "==> plugin setup smoke test"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+lua local ok, err = pcall(function() require('cplug').setup() end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "==> compile-and-debug entrypoint smoke test"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+lua local ok, err = pcall(function() require('cplug').setup(); require('cplug').compile_and_debug() end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "==> healthcheck smoke test"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+lua local ok, err = pcall(function() vim.cmd('checkhealth cplug') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall
