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
   Implement the top-level `<leader>c` flow and a shared backend contract covering detection, scaffold policy, build, and debug resolution.
3. **Launch.json support**
   Load existing `.vscode/launch.json`, choose the active configuration, and generate minimal configs when missing.
4. **DAP and UI integration**
   Wire resolved configs into `nvim-dap`, auto-open `nvim-dap-ui`, and expose optional default stepping/motion keymaps.
5. **Panel fullscreen-tab workflows**
   Add a simple, high-priority way to open a focused debug panel such as Scopes or REPL in its own fullscreen tab, exposed through a clear user command and/or optional keybind rather than burying it inside layout switching.
6. **C/C++ backend**
   Detect CMake projects, prompt before generating `CMakeLists.txt`, `.clang-format`, and `launch.json` for empty repos, then configure and build Debug targets.
7. **Rust backend**
   Detect `Cargo.toml`, build with Cargo in debug mode, and resolve launch targets for binaries.
8. **Python backend**
   Detect Python projects, resolve interpreter/program defaults, generate `launch.json` when needed, and run a debug session without adding packaging assumptions.
9. **Automated test harness**
   Add unit tests for parsing/detection, integration tests for orchestration, and at least one real end-to-end Python debugging fixture that proves the plugin can drive a debug session through `nvim-dap`.
   Include an early fixture that locks in nested Python source discovery and ignored-directory behavior (for example `src/pkg/app.py` versus `.venv` content).
10. **Coverage expansion**
   Add fixture-based tests for C/C++ and Rust flows, keeping the suite deterministic and reviewable while expanding real-toolchain coverage where practical.
   Add a focused regression test for empty C/C++ project bootstrapping, especially the C++ path, and consider a small optional demo script that lets local users inspect the generated files and flow in a toy empty C++ project.

## Notes and assumptions

- `.vscode/launch.json` is the single source of truth for debug setup in v1.
- v1 assumes `nvim-dap`, `nvim-dap-ui`, and language-specific debuggers/adapters are already installed.
- For the main compile entrypoint, missing project scaffolding should default to automatic generation, with a configurable policy for prompting or disabling when needed.
- Generated CMake templates should enable `compile_commands.json` export and default local builds to Debug mode.
- Rust support is for existing Cargo projects; Python support focuses on existing script/module-style projects.
- Python support should grow to account for common environment runners such as `uv` when resolving interpreters and launch behavior.
- The command surface should grow beyond `:CPlugCompileDebug` to cover direct workflow commands where they add clarity, especially for CMake-oriented flows such as configure-only, build-once, and build-and-run style actions.
- First-class attach workflows should become a priority across supported backends, especially Python, so users can attach to an already-running debug server without treating attach as an incidental side effect of the compile-and-debug pipeline.
  That should include a clearer command path, attach-oriented `launch.json` generation or templates, and a decision about when attach flows should skip build/scaffold work entirely.
  It should also include proper end-to-end testing and demo coverage for both attach-to-server and attach-to-process flows, rather than stopping at config generation or thin headless stubs.
- Add template-only generation commands later so users can request scaffold output without entering the full build/debug path, especially for CMake project files such as `CMakeLists.txt`, `.clang-format`, and related starter layout generation.
  Revisit command naming before implementation; prefer a clear generation-oriented verb over awkward `Gen...` abbreviations.
- Terminal-oriented workflow commands should be revisited after the run path settles, especially to move build-style commands onto `vim.fn.termopen` flows with automatic terminal closure on successful builds.
- Support non-Debug build modes later, including a clear policy for default mode selection and how direct workflow commands expose alternatives such as Release without bloating the primary fast path.
- The main `<leader>c` flow should be revisited to decide whether compile-and-debug ought to include a build-and-run step before launching the debugger, and whether that should be the default behavior or a user-configurable policy.
- Add a default keymap on `<leader>gg` to toggle `nvim-dap-ui` visibility without starting or stopping the debug session.
- Higher priority than broader layout presets: users should be able to open one panel, such as Scopes or REPL, in a dedicated fullscreen tab with an easy entrypoint, ideally a user command and optionally a default keybind.
- Native-language debugging should later support an optional disassembly view for C, C++, and Rust sessions, with a clear decision about when it appears and how it integrates with the main workflow.
- Debug UI layout handling should grow beyond a single default arrangement to support switching between layouts such as a standard view, code-plus-REPL, and other focused workspace modes.
- Future low-level language coverage should expand to include Zig, including both backend support and native-debug layout integration.
- The plugin should keep startup cost near zero by doing detection/build work only after the first mapped action.
- The first end-to-end debug proof should target Python because it is the cheapest path to a real, automated debugging test; once that harness exists, C/C++ and Rust coverage can be layered in behind it.
- Low priority: revisit whether the regression scripts and local C++ demo should become more self-contained by bootstrapping Neovim and DAP dependencies instead of assuming they already exist on the user machine, and decide that only after weighing complexity, network requirements, and maintenance cost.
- Favor a pure-Lua implementation unless a very small external helper becomes clearly necessary.
- In the final stage, revisit whether any core utilities should move out of Lua into a small external helper, based on concrete pain points such as portability, process control, filesystem handling, or maintainability tradeoffs rather than aesthetics alone.
- Make the plugin load lazily
