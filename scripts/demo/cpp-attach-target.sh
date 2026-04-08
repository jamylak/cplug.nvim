#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
usage: sh scripts/demo/cpp-attach-target.sh

Builds and runs a long-lived native process for the C++ attach demo.
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

DEMO_DIR=$TMP_BASE/cplug-cpp-attach-demo

ensure_cpp_attach_project "$DEMO_DIR"
TARGET_BIN=$(build_cpp_attach_target "$DEMO_DIR")

printf '%s\n' "cpp attach target project: $DEMO_DIR"
printf '%s\n' "target binary: $TARGET_BIN"
printf '%s\n' "next:"
printf '%s\n' "  1. In another terminal: sh scripts/demo/cpp-attach-editor.sh"
printf '%s\n' "  2. In Neovim: :CPlugAttach"
printf '%s\n' "starting native target..."

cd "$DEMO_DIR"
exec "$TARGET_BIN"
