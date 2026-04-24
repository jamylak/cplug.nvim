#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NVIM=${NVIM:-nvim}
TMP_BASE=${TMPDIR:-/tmp}
TEST_ROOT=$(mktemp -d "$TMP_BASE/cplug-zero-config.XXXXXX")
TEST_ROOT_REAL=$(cd "$TEST_ROOT" && pwd -P)

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT INT TERM

FAKE_LLDB="$TEST_ROOT/fake-lldb-dap"

cat > "$FAKE_LLDB" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_LLDB"

echo "==> zero-config empty C++ debug path"
CPP_DIR="$TEST_ROOT/cpp"
mkdir -p "$CPP_DIR"

"$NVIM" --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $CPP_DIR" \
  "+lua local ok, err = pcall(function() local original_exepath = vim.fn.exepath; vim.fn.exepath = function(bin) if bin == 'lldb-dap' then return '$FAKE_LLDB' end return original_exepath(bin) end; vim.fn.confirm = function() error('confirm should not be called for zero-config launch/scaffold') end; package.loaded['dap'] = { adapters = {}, run = function(cfg) vim.g.cplug_zero_cpp_launch = cfg end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup(); local result, run_err = require('cplug').compile_and_debug(); vim.fn.exepath = original_exepath; assert(result, run_err); assert(result.backend == 'cmake'); assert(vim.fn.filereadable('src/main.cpp') == 1); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(type(package.loaded['dap'].adapters.lldb) == 'table'); assert(package.loaded['dap'].adapters.lldb.command == '$FAKE_LLDB'); local lines = vim.fn.readfile('.vscode/launch.json'); assert(#lines > 1, 'expected pretty launch.json'); assert(vim.g.cplug_zero_cpp_launch.program:find('/build/', 1, true) ~= nil) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "==> zero-config Python debug path"
PY_DIR="$TEST_ROOT/python"
mkdir -p "$PY_DIR"

cat > "$PY_DIR/app.py" <<'EOF'
print("hello from cplug zero-config python")
EOF

"$NVIM" --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $PY_DIR" \
  "+lua local ok, err = pcall(function() local original_exepath = vim.fn.exepath; local original_system = vim.system; vim.fn.exepath = function(bin) if bin == 'uv' then return '/fake/uv' end if bin == 'python3' then return '/fake/python3' end return original_exepath(bin) end; vim.system = function(args, opts) return { wait = function() if tostring(args[1]):find('/%.venv/bin/python$') or args[1] == '/fake/python3' then return { code = vim.fn.filereadable('.debugpy-installed') == 1 and 0 or 1, stdout = '', stderr = '' } end if args[1] == 'uv' and args[2] == 'venv' then vim.fn.mkdir('.venv/bin', 'p'); vim.fn.writefile({ '#!/bin/sh', 'exit 0' }, '.venv/bin/python'); vim.fn.system({ 'chmod', '+x', '.venv/bin/python' }); return { code = 0, stdout = '', stderr = '' } end if args[1] == 'uv' and args[2] == 'pip' then vim.fn.writefile({ 'ok' }, '.debugpy-installed'); return { code = 0, stdout = '', stderr = '' } end error('unexpected command: ' .. vim.inspect(args)) end } end; vim.fn.confirm = function() error('confirm should not be called for zero-config launch') end; package.loaded['dap'] = { adapters = {}, run = function(cfg) vim.g.cplug_zero_python_launch = cfg end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup(); local result, run_err = require('cplug').compile_and_debug(); vim.fn.exepath = original_exepath; vim.system = original_system; assert(result, run_err); assert(result.backend == 'python'); assert(result.build.debugpy.bootstrapped == true); assert(vim.fn.filereadable('.vscode/launch.json') == 1); assert(type(package.loaded['dap'].adapters.python) == 'table'); assert(package.loaded['dap'].adapters.python.command == vim.g.cplug_zero_python_launch.python); assert(vim.g.cplug_zero_python_launch.program == (vim.fn.getcwd() .. '/app.py'):gsub('^/tmp/', '/private/tmp/')); assert(vim.g.cplug_zero_python_launch.console == 'internalConsole'); assert(vim.g.cplug_zero_python_launch.redirectOutput == true); local lines = vim.fn.readfile('.vscode/launch.json'); assert(#lines > 1, 'expected pretty launch.json'); local launch = vim.json.decode(table.concat(lines, '\\n')); assert(launch.configurations[1].console == 'internalConsole'); assert(launch.configurations[1].redirectOutput == true) end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "==> zero-config Rust debug path"
RUST_DIR="$TEST_ROOT/rust"
RUST_DIR_REAL="$TEST_ROOT_REAL/rust"
mkdir -p "$RUST_DIR/src" "$RUST_DIR/target/debug"

cat > "$RUST_DIR/Cargo.toml" <<'EOF'
[package]
name = "hello-zero-rust"
version = "0.1.0"
edition = "2021"
EOF

cat > "$RUST_DIR/src/main.rs" <<'EOF'
fn main() {
    println!("hello from cplug zero-config rust");
}
EOF

cat > "$RUST_DIR/target/debug/hello-zero-rust" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$RUST_DIR/target/debug/hello-zero-rust"

"$NVIM" --headless -u NONE -i NONE \
  --cmd "set rtp+=$ROOT_DIR" \
  --cmd "cd $RUST_DIR" \
  "+lua local ok, err = pcall(function() local metadata_json = vim.json.encode({ packages = { { manifest_path = '$RUST_DIR_REAL/Cargo.toml', targets = { { name = 'hello-zero-rust', kind = { 'bin' } } } } } }); local original_system = vim.system; vim.system = function(args, opts) return { wait = function() if args[1] ~= 'cargo' then error('unexpected command: ' .. vim.inspect(args)) end if args[2] == 'build' then return { code = 0, stdout = '', stderr = '' } end if args[2] == 'metadata' then return { code = 0, stdout = metadata_json, stderr = '' } end error('unexpected cargo invocation: ' .. table.concat(args, ' ')) end } end; local original_exepath = vim.fn.exepath; vim.fn.exepath = function(bin) if bin == 'lldb-dap' then return '$FAKE_LLDB' end return original_exepath(bin) end; vim.fn.confirm = function() error('confirm should not be called for zero-config launch') end; package.loaded['dap'] = { adapters = {}, run = function(cfg) vim.g.cplug_zero_rust_launch = cfg end }; package.loaded['dapui'] = { setup = function() end, open = function() end, close = function() end }; require('cplug').setup(); local result, run_err = require('cplug').compile_and_debug(); vim.system = original_system; vim.fn.exepath = original_exepath; assert(result, run_err); assert(result.backend == 'rust'); assert(type(package.loaded['dap'].adapters.lldb) == 'table'); assert(package.loaded['dap'].adapters.lldb.command == '$FAKE_LLDB'); assert(vim.g.cplug_zero_rust_launch.program == (vim.fn.getcwd() .. '/target/debug/hello-zero-rust'):gsub('^/tmp/', '/private/tmp/')); local lines = vim.fn.readfile('.vscode/launch.json'); assert(#lines > 1, 'expected pretty launch.json') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
  +qall

echo "zero-config debug test passed"
