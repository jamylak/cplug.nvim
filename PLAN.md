# cplug.nvim implementation plan

## Problem

Build a new Neovim plugin from scratch that makes `<leader>c` the "compile and debug" entrypoint for small local projects. In v1 it should:

- detect or scaffold supported project types,
- use `.vscode/launch.json` as the canonical debug configuration,
- build in debug mode where applicable,
- launch `nvim-dap` plus `nvim-dap-ui`,
- support stepping-style keymaps such as `<leader>gn`,
- stay easy to add to both a plain Neovim config and `lazy.nvim`,
- load fast and defer work until the first relevant key press,
- be developed in small, reviewable diffs with strong automated tests.

## Proposed approach

Treat the plugin as a thin orchestrator with a few clean subsystems:

1. **Core entrypoint**: one public action for "compile and debug" that runs detection, optional scaffolding, build, launch resolution, and DAP startup.
2. **Project backends**: separate C/C++, Rust, and Python implementations behind a shared interface so we can add languages without rewriting the core flow.
3. **Launch config layer**: always read `.vscode/launch.json` first; if it does not exist, offer to generate a minimal, language-appropriate file.
4. **Build layer**: invoke the native toolchain (`cmake`, `cargo`, Python interpreter) with debug-oriented defaults, but do not own debugger or adapter installation in v1.
5. **DAP bridge**: translate resolved launch settings into `nvim-dap` calls and open `nvim-dap-ui` automatically.
6. **Integration surface**: support a direct `setup()` path for plain configs and a small `lazy.nvim` example with lazy-loading on keys.

## Iterative milestones

1. **Plugin skeleton**
   Create the Lua module layout, public `setup()` API, commands, health checks, and minimal docs/examples for plain Neovim and `lazy.nvim`.
2. **Core orchestration**
   Implement the top-level `<leader>c` flow and a shared backend contract covering detection, scaffold prompt, build, and debug resolution.
3. **Launch.json support**
   Load existing `.vscode/launch.json`, choose the active configuration, and generate minimal configs when missing.
4. **DAP and UI integration**
   Wire resolved configs into `nvim-dap`, auto-open `nvim-dap-ui`, and expose optional default stepping/motion keymaps.
5. **C/C++ backend**
   Detect CMake projects, prompt before generating `CMakeLists.txt`, `.clang-format`, and `launch.json` for empty repos, then configure and build Debug targets.
6. **Rust backend**
   Detect `Cargo.toml`, build with Cargo in debug mode, and resolve launch targets for binaries.
7. **Python backend**
   Detect Python projects, resolve interpreter/program defaults, generate `launch.json` when needed, and run a debug session without adding packaging assumptions.
8. **Automated test harness**
   Add unit tests for parsing/detection, integration tests for orchestration, and at least one real end-to-end Python debugging fixture that proves the plugin can drive a debug session through `nvim-dap`.
   Include an early fixture that locks in nested Python source discovery and ignored-directory behavior (for example `src/pkg/app.py` versus `.venv` content).
9. **Coverage expansion**
   Add fixture-based tests for C/C++ and Rust flows, keeping the suite deterministic and reviewable while expanding real-toolchain coverage where practical.

## Notes and assumptions

- `.vscode/launch.json` is the single source of truth for debug setup in v1.
- v1 assumes `nvim-dap`, `nvim-dap-ui`, and language-specific debuggers/adapters are already installed.
- For empty C/C++ repos, scaffolding should be **prompted**, not silently generated.
- Generated CMake templates should enable `compile_commands.json` export and default local builds to Debug mode.
- Rust support is for existing Cargo projects; Python support focuses on existing script/module-style projects.
- Python support should grow to account for common environment runners such as `uv` when resolving interpreters and launch behavior.
- The command surface should grow beyond `:CPlugCompileDebug` to cover direct workflow commands where they add clarity, especially for CMake-oriented flows such as configure-only, build-once, and build-and-run style actions.
- The plugin should keep startup cost near zero by doing detection/build work only after the first mapped action.
- The first end-to-end debug proof should target Python because it is the cheapest path to a real, automated debugging test; once that harness exists, C/C++ and Rust coverage can be layered in behind it.
- Favor a pure-Lua implementation unless a very small external helper becomes clearly necessary.
