#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh "$ROOT_DIR/scripts/headless-smoke.sh"
sh "$ROOT_DIR/scripts/test-python-nested-layout.sh"
sh "$ROOT_DIR/scripts/test-python-interpreter-resolution.sh"
sh "$ROOT_DIR/scripts/test-python-attach.sh"
sh "$ROOT_DIR/scripts/test-cmake-template-generation.sh"
sh "$ROOT_DIR/scripts/test-cmake-configure-terminal.sh"
sh "$ROOT_DIR/scripts/test-cmake-configure-terminal-persist.sh"
sh "$ROOT_DIR/scripts/test-cmake-launch-generation.sh"
sh "$ROOT_DIR/scripts/test-cmake-attach.sh"
sh "$ROOT_DIR/scripts/test-cmake-disassembly-layout.sh"
sh "$ROOT_DIR/scripts/test-cmake-git-bootstrap.sh"
sh "$ROOT_DIR/scripts/test-cmake-build-once-terminal.sh"
sh "$ROOT_DIR/scripts/test-cmake-build-once-terminal-persist.sh"
sh "$ROOT_DIR/scripts/test-cmake-build-and-run-terminal.sh"
sh "$ROOT_DIR/scripts/test-cmake-empty-cpp-bootstrap.sh"
sh "$ROOT_DIR/scripts/test-rust-launch-generation.sh"

echo "all tests passed"
