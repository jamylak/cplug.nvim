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
- a minimal Python backend for existing projects

DAP startup and the other language backends are still being added in later iterations.

Current backend scope:

- Python detection for existing projects via `pyproject.toml`, `requirements.txt`, or top-level `*.py`
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

## Launch Configs

The shared launch layer expects `.vscode/launch.json` by default, can select a named configuration via `opts.launch.configuration`, and can handle missing files with `opts.launch.on_missing`:

- `"prompt"` prompts before generating a backend-specific launch file
- `"always"` generates automatically
- `"never"` returns an error
