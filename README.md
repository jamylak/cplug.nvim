# cplug.nvim

`cplug.nvim` aims to make `<leader>c` the compile-and-debug entrypoint for small local projects.

This project currently has:

- a public `setup()` API
- a `:CPlugCompileDebug` user command
- a `:CPlugCMakeConfigure` user command
- a `:CPlugCMakeBuildOnce` user command
- a `:CPlugCMakeBuildAndRun` user command
- a `:CPlugCMakeRun` user command
- optional default keymaps
- a `:checkhealth cplug` healthcheck
- a core orchestration pipeline for detect -> optional scaffold -> build -> launch resolution
- a shared backend contract for future language implementations
- shared `.vscode/launch.json` resolution in the main pipeline
- a CMake backend for existing, source-only, and empty C/C++ projects
- an existing-project Cargo backend for Rust
- a minimal Python backend for existing projects
- `nvim-dap` / `nvim-dap-ui` startup from the resolved launch config
- automatic `nvim-dap-disasm` wiring for the default low-level UI when it is installed
- optional default DAP stepping and breakpoint keymaps

The remaining work is language expansion and adapter-specific polish.

Current backend scope:

- C/C++ detection for existing `CMakeLists.txt` projects, automatic scaffolding for source-only repos, and empty-repo bootstrapping into a minimal C++ project by default
- missing C/C++ `launch.json` generation from built CMake executables
- Rust detection for existing `Cargo.toml` projects with debug builds in `target/debug`
- missing Rust `launch.json` generation from the first Cargo binary target
- Python detection for existing projects via `pyproject.toml`, `requirements.txt`, or discovered `*.py` files in common source layouts
- Python launch generation with interpreter defaults from `.venv`, `venv`, `python3`, or `python`
- debug launch resolution through `.vscode/launch.json`
- no Python scaffolding yet

## Setup

```lua
require("cplug").setup()
```

Disable the built-in keymap if you want to own lazy-loading or mappings yourself:

```lua
require("cplug").setup({
  default_keymaps = false,
})
```

Select a specific VS Code launch configuration by name:

```lua
require("cplug").setup({
  launch = {
    configuration = "Debug current file",
  },
})
```

Auto-generate a minimal `launch.json` when one is missing:

```lua
require("cplug").setup({
  launch = {
    on_missing = "always",
  },
})
```

Control automatic project scaffolding:

```lua
require("cplug").setup({
  scaffold = {
    on_missing = "always",
  },
  c_family = {
    empty_project_language = "cpp",
  },
})
```

Disable automatic `dap-ui` opening:

```lua
require("cplug").setup({
  dap = {
    open_ui = false,
  },
})
```

Pick a default managed DAP UI layout:

```lua
require("cplug").setup({
  dap = {
    layout = "code_repl",
  },
})
```

Let cplug own the default `dapui` layout setup explicitly:

```lua
require("cplug").setup({
  dap = {
    manage_ui_layout = true,
  },
})
```

Disable the default disassembly pane in low-level debug layouts:

```lua
require("cplug").setup({
  dap = {
    disassembly = {
      enabled = false,
    },
  },
})
```

If you disable cplug-managed UI layouts, you own the `dapui` layout and must
add `disassembly` yourself if you still want that pane:

```lua
require("cplug").setup({
  dap = {
    manage_ui_layout = false,
    disassembly = {
      enabled = true,
    },
  },
})

require("dapui").setup({
  layouts = {
    {
      elements = {
        { id = "scopes", size = 0.25 },
        { id = "breakpoints", size = 0.25 },
        { id = "stacks", size = 0.25 },
        { id = "watches", size = 0.25 },
      },
      position = "left",
      size = 40,
    },
    {
      elements = {
        { id = "disassembly", size = 0.7 },
        { id = "repl", size = 0.3 },
      },
      position = "bottom",
      size = 16,
    },
  },
})
```

Override the default CMake build directory:

```lua
require("cplug").setup({
  c_family = {
    build_dir = "build",
  },
})
```

Skip `.clang-format` generation during C/C++ scaffolding:

```lua
require("cplug").setup({
  c_family = {
    generate_clang_format = false,
  },
})
```

Default scaffolded C/C++ templates can seed `CPLUG_WARNINGS_AS_ERRORS`:

```lua
require("cplug").setup({
  c_family = {
    warnings_as_errors = true,
  },
})
```

Bootstrap Git during C/C++ scaffolding:

```lua
require("cplug").setup({
  c_family = {
    bootstrap_git = false,
  },
})
```

Keep the `:CPlugCMakeBuildOnce` terminal open after a successful build:

```lua
require("cplug").setup({
  c_family = {
    keep_build_terminal_open = true,
  },
})
```

Keep the `:CPlugCMakeConfigure` terminal open after a successful configure:

```lua
require("cplug").setup({
  c_family = {
    keep_configure_terminal_open = true,
  },
})
```

Override the Python interpreter used in generated launch configs:

```lua
require("cplug").setup({
  python = {
    interpreter = "/path/to/python",
  },
})
```

Default stepping keymaps:

- `<leader>gg` toggle debug UI
- `<leader>gc` continue
- `<leader>gx` terminate
- `<leader>gn` step over
- `<leader>gi` step into
- `<leader>go` step out
- `<leader>gb` toggle breakpoint

## lazy.nvim

```lua
{
  "jamylak/cplug.nvim",
  dependencies = {
    "mfussenegger/nvim-dap",
    "nvim-neotest/nvim-nio",
    "rcarriga/nvim-dap-ui",
    "Jorenar/nvim-dap-disasm",
  },
  keys = {
    {
      "<leader>c",
      function()
        require("cplug").compile_and_debug()
      end,
      desc = "Compile and debug",
    },
  },
  config = function()
    require("cplug").setup({
      default_keymaps = false,
    })
  end,
}
```

## Health

Run:

```vim
:checkhealth cplug
```

The healthcheck warns when `nvim-dap`, `nvim-dap-ui`, or `nvim-dap-disasm` are missing from `runtimepath`.

## Tests

Run the current regression scripts with:

```sh
make test
```

Try the plugin locally against a toy or empty C++ project with:

```sh
sh scripts/run-cpp-demo.sh toy
sh scripts/run-cpp-demo.sh empty
```

The demo runner sets `<leader>` to `<Space>`, enables automatic project and
launch scaffolding, and will also add local `nvim-dap`, `nvim-dap-ui`, and
`nvim-dap-disasm` installations plus an LLDB adapter when they are already
available on your machine. That lets you use `<Space>c` and the default
`<Space>g...` debug mappings directly in the demo session, including
`<Space>gl` for the layout picker.

## DAP Startup

Once a backend and launch config are resolved, cplug passes the selected configuration to `nvim-dap` and opens `nvim-dap-ui` by default. cplug manages named `dapui` layout presets unless you set `dap.manage_ui_layout = false`.

By default `dap.layout = "auto"`:

- non-low-level adapters use the `standard` layout
- low-level adapters use the `native` layout

Available managed presets:

- `standard`
- `native`
- `code_repl`
- `stack_focus`
- `repl_only`

You can switch layouts at runtime with `:CPlugLayout` or the default
`<leader>gl` keymap. `:CPlugLayout` with no argument opens a built-in floating
picker with fuzzy filtering.
Low-level sessions use the disassembly pane in the `native` layout when
`Jorenar/nvim-dap-disasm` is installed; disable that with
`dap.disassembly.enabled = false`.

## DAP Keymaps

When `default_keymaps = true`, cplug also registers a small set of DAP action mappings:

- `toggle debug UI` on `<leader>gg`
- `pick debug UI layout` on `<leader>gl`
- `continue` on `<leader>gc`
- `terminate` on `<leader>gx`
- `step over` on `<leader>gn`
- `step into` on `<leader>gi`
- `step out` on `<leader>go`
- `toggle breakpoint` on `<leader>gb`

## Launch Configs

The shared launch layer expects `.vscode/launch.json` by default, can select a named configuration via `opts.launch.configuration`, and can handle missing files with `opts.launch.on_missing`:

- `"prompt"` prompts before generating a backend-specific launch file
- `"always"` generates automatically
- `"never"` returns an error

Project scaffolding uses `opts.scaffold.on_missing` with the same modes, and
defaults to `"always"` so `<leader>c` will generate missing C/C++ project
files automatically.

## CMake Configure

Run:

```vim
:CPlugCMakeConfigure
```

This reuses the CMake backend detection and scaffolding flow, then runs a Debug configure step into the configured build directory without starting DAP.
It opens the configure step in a terminal split, keeps failures visible, and closes the terminal automatically when configuration succeeds unless `c_family.keep_configure_terminal_open = true`.

## CMake Build Once

Run:

```vim
:CPlugCMakeBuildOnce
```

This reuses the same CMake detection and scaffolding flow, then performs a one-off Debug build into the configured build directory without starting DAP.
It opens the build in a terminal split, keeps failures visible, and closes the terminal automatically when the build succeeds unless `c_family.keep_build_terminal_open = true`.

## CMake Build And Run

Run:

```vim
:CPlugCMakeBuildAndRun
```

This reuses the same CMake detection and scaffolding flow, performs a Debug build, and runs the first built executable without starting DAP.
It now runs the build in a terminal first, then starts the executable in a second terminal only after the build succeeds.

## CMake Run

Run:

```vim
:CPlugCMakeRun
```

This runs the first built executable from the configured CMake build directory without rebuilding first.
It opens the executable in a terminal split, focuses that window, and enters insert mode so live output stays visible while the process runs.

## Layout Picker

Run:

```vim
:CPlugLayout
```

With no argument, this opens the managed DAP layout picker through
the built-in floating picker. Start typing to fuzzy-filter the available
layouts, then press `<CR>` to switch.

You can also set a layout directly:

```vim
:CPlugLayout code_repl
:CPlugLayout native
:CPlugLayout auto
```
