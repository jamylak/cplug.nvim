#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

echo "==> plugin setup smoke test"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+lua require('cplug').setup()" \
  +qall

echo "==> compile-and-debug entrypoint smoke test"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+lua require('cplug').setup(); require('cplug').compile_and_debug()" \
  +qall

echo "==> healthcheck smoke test"
nvim --headless -u NONE -i NONE --cmd "set rtp+=$ROOT_DIR" \
  "+checkhealth cplug" \
  +qall
