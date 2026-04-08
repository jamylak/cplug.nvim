#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}

find_plugin_dir() {
  plugin_name=$1

  for pattern in \
    "$HOME/.local/share/nvim/lazy/$plugin_name" \
    "$HOME/.local/share/nvim/site/pack/"*/start/"$plugin_name" \
    "$HOME/.config/nvim/pack/"*/start/"$plugin_name"
  do
    for candidate in $pattern; do
      if [ -d "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  done

  return 1
}

append_plugin_init() {
  plugin_dir=$1
  init_file=$2

  if [ -z "$plugin_dir" ] || [ ! -d "$plugin_dir" ]; then
    return 0
  fi

  cat >> "$init_file" <<EOF
vim.opt.runtimepath:append([[$plugin_dir]])
package.path = package.path .. ";$plugin_dir/lua/?.lua;$plugin_dir/lua/?/init.lua"
EOF
}

usage() {
  cat <<'EOF'
usage: sh scripts/run-cpp-demo.sh [toy|empty] [-- <extra nvim args>]

examples:
  sh scripts/run-cpp-demo.sh toy
  sh scripts/run-cpp-demo.sh empty
  sh scripts/run-cpp-demo.sh toy -- --headless +qall
EOF
}

MODE=${1:-toy}

case "$MODE" in
  toy|empty)
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

shift || true

if [ "${1:-}" = "--" ]; then
  shift
fi

DEMO_DIR=$(mktemp -d "$TMP_BASE/cplug-cpp-demo-$MODE.XXXXXX")
STATE_DIR=$(mktemp -d "$TMP_BASE/cplug-cpp-state.XXXXXX")
INIT_FILE=$STATE_DIR/init.lua
XDG_STATE_HOME=$STATE_DIR/state
mkdir -p "$XDG_STATE_HOME"

cleanup() {
  rm -rf "$STATE_DIR"
}

trap cleanup EXIT INT TERM

if [ "$MODE" = "toy" ]; then
  cat > "$DEMO_DIR/main.cpp" <<'EOF'
#include <iostream>

int main() {
  std::cout << "hello from cplug demo" << std::endl;
  return 0;
}
EOF
  TARGET_FILE=$DEMO_DIR/main.cpp
else
  TARGET_FILE=
fi

DAP_DIR=
if DAP_DIR=$(find_plugin_dir nvim-dap 2>/dev/null); then
  :
else
  DAP_DIR=
fi

DAPUI_DIR=
if DAPUI_DIR=$(find_plugin_dir nvim-dap-ui 2>/dev/null); then
  :
else
  DAPUI_DIR=
fi

DISASM_DIR=
if DISASM_DIR=$(find_plugin_dir nvim-dap-disasm 2>/dev/null); then
  :
else
  DISASM_DIR=
fi

NIO_DIR=
if NIO_DIR=$(find_plugin_dir nvim-nio 2>/dev/null); then
  :
else
  NIO_DIR=
fi

NUI_DIR=
if NUI_DIR=$(find_plugin_dir nui.nvim 2>/dev/null); then
  :
else
  NUI_DIR=
fi

LLDB_COMMAND=
for candidate in lldb-dap codelldb lldb-vscode; do
  if command -v "$candidate" >/dev/null 2>&1; then
    LLDB_COMMAND=$(command -v "$candidate")
    break
  fi
done

cat > "$INIT_FILE" <<EOF
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.runtimepath:append("$ROOT_DIR")
package.path = package.path .. ";$ROOT_DIR/lua/?.lua;$ROOT_DIR/lua/?/init.lua"
EOF

append_plugin_init "$DAP_DIR" "$INIT_FILE"
append_plugin_init "$DAPUI_DIR" "$INIT_FILE"
append_plugin_init "$DISASM_DIR" "$INIT_FILE"
append_plugin_init "$NIO_DIR" "$INIT_FILE"
append_plugin_init "$NUI_DIR" "$INIT_FILE"

cat >> "$INIT_FILE" <<EOF
local ok_dap, dap = pcall(require, "dap")

if ok_dap then
EOF

if [ -n "$LLDB_COMMAND" ]; then
  cat >> "$INIT_FILE" <<EOF
  dap.adapters.lldb = {
    type = "executable",
    command = "$LLDB_COMMAND",
    name = "lldb",
  }
EOF
fi

cat >> "$INIT_FILE" <<'EOF'
end

local ok_dapui, dapui = pcall(require, "dapui")

if ok_dapui and type(dapui.setup) == "function" then
  dapui.setup()
end

require("cplug").setup({
  launch = {
    on_missing = "always",
  },
  scaffold = {
    on_missing = "always",
  },
})
EOF

printf '%s\n' "cplug demo project: $DEMO_DIR"
printf '%s\n' "mode: $MODE"
printf '%s\n' "leader: <Space>"
printf '%s\n' "nvim-dap: ${DAP_DIR:-not found}"
printf '%s\n' "nvim-dap-ui: ${DAPUI_DIR:-not found}"
printf '%s\n' "nvim-dap-disasm: ${DISASM_DIR:-not found}"
printf '%s\n' "nvim-nio: ${NIO_DIR:-not found}"
printf '%s\n' "nui.nvim: ${NUI_DIR:-not found}"
printf '%s\n' "lldb adapter: ${LLDB_COMMAND:-not found}"
printf '%s\n' "default keymaps:"
printf '%s\n' "  <Space>c  compile and debug"
printf '%s\n' "  <Space>gc continue"
printf '%s\n' "  <Space>gx terminate"
printf '%s\n' "  <Space>gn step over"
printf '%s\n' "  <Space>gi step into"
printf '%s\n' "  <Space>go step out"
printf '%s\n' "  <Space>gb toggle breakpoint"
printf '%s\n' "other useful commands:"
printf '%s\n' "  :CPlugCompileDebug"
printf '%s\n' "  :CPlugCMakeConfigure"
printf '%s\n' "  :CPlugCMakeBuildOnce"
printf '%s\n' "  :CPlugCMakeBuildAndRun"

if [ "$MODE" = "empty" ]; then
  printf '%s\n' "empty mode starts with no source files so you can exercise the empty C++ bootstrap flow."
fi

if [ -n "$TARGET_FILE" ]; then
  exec env XDG_STATE_HOME="$XDG_STATE_HOME" nvim -n -u "$INIT_FILE" -i NONE \
    --cmd "cd $DEMO_DIR" \
    "$@" \
    "$TARGET_FILE"
fi

exec env XDG_STATE_HOME="$XDG_STATE_HOME" nvim -n -u "$INIT_FILE" -i NONE \
  --cmd "cd $DEMO_DIR" \
  "$@"
