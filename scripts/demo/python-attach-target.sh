#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
usage: sh scripts/demo/python-attach-target.sh

Starts a local debugpy server for the Python attach demo.
EOF
}

case "${1:-}" in
  "" )
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

DEMO_DIR=$TMP_BASE/cplug-python-attach-demo

ensure_python_attach_project "$DEMO_DIR"

if DEMO_PYTHON=$(ensure_demo_python "$DEMO_DIR" 2>/dev/null); then
  :
else
  printf '%s\n' "failed to bootstrap $DEMO_DIR/.venv with debugpy" >&2
  exit 1
fi

printf '%s\n' "python attach target project: $DEMO_DIR"
printf '%s\n' "demo python: $DEMO_PYTHON"
printf '%s\n' "next:"
printf '%s\n' "  1. In another terminal: sh scripts/demo/python-attach-editor.sh"
printf '%s\n' "  2. In Neovim: :CPlugAttach"
printf '%s\n' "starting debugpy target on 127.0.0.1:5678..."

cd "$DEMO_DIR"
exec "$DEMO_PYTHON" -u -m debugpy --listen 127.0.0.1:5678 --wait-for-client attach_target.py
