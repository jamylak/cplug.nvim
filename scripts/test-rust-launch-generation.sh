#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_BASE=${TMPDIR:-/tmp}
TEST_DIR=$(mktemp -d "$TMP_BASE/cplug-rust-launch.XXXXXX")
TEST_DIR_REAL=$(cd "$TEST_DIR" && pwd -P)

cleanup() {
  rm -rf "$TEST_DIR"
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
nvim --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $TEST_DIR" \
  "+lua local ok, err = pcall(function() local metadata_json = vim.json.encode({ packages = { { manifest_path = '$TEST_DIR_REAL/Cargo.toml', targets = { { name = 'hello-rust', kind = { 'bin' } } } } } }); local original_system = vim.system; vim.system = function(args, opts) return { wait = function() if args[1] ~= 'cargo' then error('unexpected command: ' .. vim.inspect(args)) end if args[2] == 'build' then return { code = 0, stdout = '', stderr = '' } end if args[2] == 'metadata' then return { code = 0, stdout = metadata_json, stderr = '' } end error('unexpected cargo invocation: ' .. table.concat(args, ' ')) end } end; package.loaded['dap'] = { adapters = { lldb = {} }, run = function(cfg) vim.g.cplug_rust_launch = cfg end }; package.loaded['dapui'] = { open = function() end }; require('cplug').setup({ launch = { on_missing = 'always' } }); local result, run_err = require('cplug').compile_and_debug(); vim.system = original_system; assert(result, run_err); assert(result.backend == 'rust'); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(vim.g.cplug_rust_launch.program == (vim.fn.getcwd() .. '/target/debug/hello-rust'):gsub('^/tmp/', '/private/tmp/')) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "rust launch generation test passed"
