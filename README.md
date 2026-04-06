# cplug.nvim

`cplug.nvim` aims to make `<leader>c` the compile-and-debug entrypoint for small local projects.

This project currently has:

- a public `setup()` API
- a `:CPlugCompileDebug` user command
- optional default keymaps
- a `:checkhealth cplug` healthcheck
- a core orchestration pipeline for detect -> optional scaffold -> build -> launch resolution
- a shared backend contract for future language implementations
- shared `.vscode/launch.json` resolution in the main pipeline
- an existing-project CMake backend for C/C++
- an existing-project Cargo backend for Rust
- a minimal Python backend for existing projects
- `nvim-dap` / `nvim-dap-ui` startup from the resolved launch config
- optional default DAP stepping and breakpoint keymaps

The remaining work is language expansion and adapter-specific polish.

Current backend scope:

- C/C++ detection for existing `CMakeLists.txt` projects with Debug builds in `build`
- missing C/C++ `launch.json` generation from built CMake executables
- Rust detection for existing `Cargo.toml` projects with debug builds in `target/debug`
- missing Rust `launch.json` generation from the first Cargo binary target
- Python detection for existing projects via `pyproject.toml`, `requirements.txt`, or top-level `*.py`
- Python launch generation with interpreter defaults from `.venv`, `venv`, `python3`, or `python`
- debug launch resolution through `.vscode/launch.json`
- no C/C++ scaffolding yet
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

Disable automatic `dap-ui` opening:

```lua
require("cplug").setup({
  dap = {
    open_ui = false,
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

Override the Python interpreter used in generated launch configs:

```lua
require("cplug").setup({
  python = {
    interpreter = "/path/to/python",
  },
})
```

Default stepping keymaps:

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

The healthcheck warns when `nvim-dap` or `nvim-dap-ui` are missing from `runtimepath`.

## DAP Startup

Once a backend and launch config are resolved, cplug passes the selected configuration to `nvim-dap` and opens `nvim-dap-ui` by default.

## DAP Keymaps

When `default_keymaps = true`, cplug also registers a small set of DAP action mappings:

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
