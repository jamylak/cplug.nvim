#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
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

find_lldb_command() {
  for candidate in lldb-dap codelldb lldb-vscode; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  return 1
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

  mkdir -p "$demo_dir"

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

ensure_python_attach_project() {
  demo_dir=$1

  mkdir -p "$demo_dir/.vscode"

  cat > "$demo_dir/app.py" <<'EOF'
def main():
  print("hello from cplug python attach demo")


if __name__ == "__main__":
  main()
EOF

  cat > "$demo_dir/attach_target.py" <<'EOF'
import time


def main():
  print("python attach target running")

  for tick in range(120):
    print(f"tick {tick}", flush=True)
    time.sleep(1)


if __name__ == "__main__":
  main()
EOF
}

ensure_cpp_attach_project() {
  demo_dir=$1

  mkdir -p "$demo_dir/.vscode"

  cat > "$demo_dir/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(cplug_cpp_attach_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(cplug_cpp_attach_demo main.cpp)
EOF

  cat > "$demo_dir/main.cpp" <<'EOF'
#include <chrono>
#include <iostream>
#include <thread>

int main() {
  std::cout << "cplug cpp attach demo running" << std::endl;

  for (int tick = 0; tick < 120; ++tick) {
    std::cout << "tick " << tick << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(1));
  }

  return 0;
}
EOF
}

build_cpp_attach_target() {
  demo_dir=$1
  build_dir=$demo_dir/build

  if ! command -v cmake >/dev/null 2>&1; then
    printf '%s\n' "cmake is required for the C++ attach demo" >&2
    return 1
  fi

  cmake -S "$demo_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE=Debug >/dev/null
  cmake --build "$build_dir" >/dev/null

  printf '%s\n' "$build_dir/cplug_cpp_attach_demo"
}
