#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh "$ROOT_DIR/scripts/headless-smoke.sh"
sh "$ROOT_DIR/scripts/test-python-nested-layout.sh"
sh "$ROOT_DIR/scripts/test-python-interpreter-resolution.sh"
sh "$ROOT_DIR/scripts/test-cmake-launch-generation.sh"
sh "$ROOT_DIR/scripts/test-rust-launch-generation.sh"

echo "all tests passed"
