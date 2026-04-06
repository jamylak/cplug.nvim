#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-rust-launch.XXXXXX")
BIN_DIR=$(mktemp -d "$TMP_BASE/cplug-rust-bin.XXXXXX")
TEST_DIR_REAL=$(cd "$TEST_DIR" && pwd -P)

cleanup() {
  rm -rf "$TEST_DIR" "$BIN_DIR"
}

trap cleanup EXIT INT TERM

mkdir -p "$TEST_DIR/src" "$TEST_DIR/target/debug"

cat > "$TEST_DIR/Cargo.toml" <<'EOF'
[package]
name = "hello-rust"
version = "0.1.0"
edition = "2021"
EOF

cat > "$TEST_DIR/src/main.rs" <<'EOF'
fn main() {
    println!("hello");
}
EOF

cat > "$TEST_DIR/target/debug/hello-rust" <<'EOF'
#!/bin/sh
exit 0
EOF

chmod +x "$TEST_DIR/target/debug/hello-rust"

cat > "$BIN_DIR/cargo" <<EOF
#!/bin/sh
set -eu

if [ "\$1" = "build" ]; then
  exit 0
fi

if [ "\$1" = "metadata" ]; then
  printf '%s\n' '{"packages":[{"manifest_path":"'"$TEST_DIR_REAL"'/Cargo.toml","targets":[{"name":"hello-rust","kind":["bin"]}]}]}'
  exit 0
fi

echo "unexpected cargo invocation: \$*" >&2
exit 1
EOF

chmod +x "$BIN_DIR/cargo"

PATH="$BIN_DIR:$PATH" \
nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() package.loaded['dap'] = { run = function(cfg) vim.g.cplug_rust_launch = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ launch = { on_missing = 'always' } }); local result, run_err = require('cplug').compile_and_debug(); assert(result, run_err); assert(result.backend == 'rust'); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(vim.g.cplug_rust_launch.program == (vim.fn.getcwd() .. '/target/debug/hello-rust'):gsub('^/tmp/', '/private/tmp/')) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "rust launch generation test passed"
