#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
usage: sh scripts/demo/cpp-attach-editor.sh [-- <extra nvim args>]

Opens Neovim in the C++ attach demo project.
EOF
}

case "${1:-}" in
  "" )
    ;;
  --)
    shift
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

DEMO_DIR=$TMP_BASE/cplug-cpp-attach-demo
STATE_DIR=$(mktemp -d "$TMP_BASE/cplug-cpp-attach-state.XXXXXX")
INIT_FILE=$STATE_DIR/init.lua
XDG_STATE_HOME=$STATE_DIR/state
mkdir -p "$XDG_STATE_HOME"

cleanup() {
  rm -rf "$STATE_DIR"
}

trap cleanup EXIT INT TERM

ensure_cpp_attach_project "$DEMO_DIR"

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
if LLDB_COMMAND=$(find_lldb_command 2>/dev/null); then
  :
else
  LLDB_COMMAND=
fi

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

cat >> "$INIT_FILE" <<'EOF'
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

cat >> "$INIT_FILE" <<EOF
end

local ok_dapui, dapui = pcall(require, "dapui")

if ok_dapui and type(dapui.setup) == "function" then
  dapui.setup()
end

require("cplug").setup({
  launch = {
    on_missing = "always",
    configuration = "Attach cplug-cpp-attach-demo process",
  },
  scaffold = {
    on_missing = "always",
  },
})
EOF

printf '%s\n' "cpp attach editor project: $DEMO_DIR"
printf '%s\n' "lldb adapter: ${LLDB_COMMAND:-not found}"
printf '%s\n' "nvim-dap: ${DAP_DIR:-not found}"
printf '%s\n' "nvim-dap-ui: ${DAPUI_DIR:-not found}"
printf '%s\n' "next:"
printf '%s\n' "  1. In another terminal: sh scripts/demo/cpp-attach-target.sh"
printf '%s\n' "  2. In Neovim: :CPlugAttach"

exec env XDG_STATE_HOME="$XDG_STATE_HOME" nvim -n -u "$INIT_FILE" -i NONE \
  --cmd "cd $DEMO_DIR" \
  "$@" \
  "$DEMO_DIR/main.cpp"
