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

find_base_python() {
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  return 1
}

ensure_demo_python() {
  demo_dir=$1
  demo_python=$demo_dir/.venv/bin/python

  if [ -x "$demo_python" ] && "$demo_python" -c "import debugpy" >/dev/null 2>&1; then
    printf '%s\n' "$demo_python"
    return 0
  fi

  if command -v uv >/dev/null 2>&1; then
    uv venv "$demo_dir/.venv" >/dev/null
    uv pip install --python "$demo_python" debugpy >/dev/null
  else
    base_python=$(find_base_python)
    "$base_python" -m venv "$demo_dir/.venv"
    "$demo_python" -m pip install --upgrade pip >/dev/null
    "$demo_python" -m pip install debugpy >/dev/null
  fi

  if "$demo_python" -c "import debugpy" >/dev/null 2>&1; then
    printf '%s\n' "$demo_python"
    return 0
  fi

  return 1
}

usage() {
  cat <<'EOF'
usage: sh scripts/run-python-demo.sh [toy|attach] [-- <extra nvim args>]

examples:
  sh scripts/run-python-demo.sh toy
  sh scripts/run-python-demo.sh attach
  sh scripts/run-python-demo.sh toy -- --headless +qall
EOF
}

MODE=${1:-toy}

case "$MODE" in
  toy|attach)
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

DEMO_DIR=$(mktemp -d "$TMP_BASE/cplug-python-demo-$MODE.XXXXXX")
STATE_DIR=$(mktemp -d "$TMP_BASE/cplug-python-state.XXXXXX")
INIT_FILE=$STATE_DIR/init.lua
XDG_STATE_HOME=$STATE_DIR/state
mkdir -p "$XDG_STATE_HOME"

cleanup() {
  rm -rf "$STATE_DIR"
}

trap cleanup EXIT INT TERM

cat > "$DEMO_DIR/app.py" <<'EOF'
def main():
  message = "hello from cplug python demo"
  print(message)


if __name__ == "__main__":
  main()
EOF

if [ "$MODE" = "attach" ]; then
  cat > "$DEMO_DIR/attach_server.py" <<'EOF'
import time

try:
  import debugpy
except ImportError as exc:
  raise SystemExit("debugpy is required for attach demo mode") from exc


def main():
  debugpy.listen(("127.0.0.1", 5678))
  print("debugpy listening on 127.0.0.1:5678")
  print("waiting for debugger to attach...")
  debugpy.wait_for_client()
  print("debugger attached")

  for tick in range(30):
    print(f"tick {tick}")
    time.sleep(1)


if __name__ == "__main__":
  main()
EOF
  TARGET_FILE=$DEMO_DIR/attach_server.py
else
  TARGET_FILE=$DEMO_DIR/app.py
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

DEBUGPY_PYTHON=
if DEBUGPY_PYTHON=$(ensure_demo_python "$DEMO_DIR" 2>/dev/null); then
  :
else
  printf '%s\n' "failed to bootstrap $DEMO_DIR/.venv with debugpy" >&2
  exit 1
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

cat >> "$INIT_FILE" <<EOF
local ok_dap, dap = pcall(require, "dap")

if ok_dap then
EOF

if [ -n "$DEBUGPY_PYTHON" ]; then
  cat >> "$INIT_FILE" <<EOF
  dap.adapters.python = {
    type = "executable",
    command = "$DEBUGPY_PYTHON",
    args = { "-m", "debugpy.adapter" },
  }
EOF
fi

cat >> "$INIT_FILE" <<'EOF'
end

local ok_dapui, dapui = pcall(require, "dapui")

if ok_dapui and type(dapui.setup) == "function" then
  dapui.setup()
end
EOF

cat >> "$INIT_FILE" <<EOF
require("cplug").setup({
  launch = {
    on_missing = "always",
  },
  python = {
    interpreter = "$DEBUGPY_PYTHON",
  },
})
EOF

printf '%s\n' "cplug python demo project: $DEMO_DIR"
printf '%s\n' "mode: $MODE"
printf '%s\n' "leader: <Space>"
printf '%s\n' "nvim-dap: ${DAP_DIR:-not found}"
printf '%s\n' "nvim-dap-ui: ${DAPUI_DIR:-not found}"
printf '%s\n' "nvim-dap-disasm: ${DISASM_DIR:-not found}"
printf '%s\n' "nvim-nio: ${NIO_DIR:-not found}"
printf '%s\n' "nui.nvim: ${NUI_DIR:-not found}"
printf '%s\n' "demo python: ${DEBUGPY_PYTHON:-not found}"
printf '%s\n' "default keymaps:"
printf '%s\n' "  <Space>c  compile and debug"
printf '%s\n' "  <Space>gl pick debug UI layout"
printf '%s\n' "  <Space>gc continue"
printf '%s\n' "  <Space>gx terminate"
printf '%s\n' "  <Space>gn step over"
printf '%s\n' "  <Space>gi step into"
printf '%s\n' "  <Space>go step out"
printf '%s\n' "  <Space>gb toggle breakpoint"
printf '%s\n' "other useful commands:"
printf '%s\n' "  :CPlugCompileDebug"
printf '%s\n' "  :CPlugAttach"
printf '%s\n' "  :CPlugGenerateAttach"
printf '%s\n' "  :CPlugLayout"

if [ "$MODE" = "attach" ]; then
  printf '%s\n' "attach demo steps:"
  printf '%s\n' "  1. In another terminal: cd $DEMO_DIR && $DEBUGPY_PYTHON attach_server.py"
  printf '%s\n' "  2. In Neovim: :CPlugGenerateAttach"
  printf '%s\n' "  3. In Neovim: :CPlugAttach"
fi

exec env XDG_STATE_HOME="$XDG_STATE_HOME" nvim -n -u "$INIT_FILE" -i NONE \
  --cmd "cd $DEMO_DIR" \
  "$@" \
  "$TARGET_FILE"
