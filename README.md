# cplug.nvim

`cplug.nvim` aims to make `<leader>c` the compile-and-debug entrypoint for small local projects.

This project currently has:

- a public `setup()` API
- a `:CPlugCompileDebug` user command
- optional default keymaps
- a `:checkhealth cplug` healthcheck
- a core orchestration pipeline for detect -> optional scaffold -> build -> launch resolution
- a shared backend contract for future language implementations

Language backends and DAP startup are still being added in later iterations, so the command currently reports when no supported project backend is available.

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

The shared launch layer now expects `.vscode/launch.json` by default and can select a named configuration via `opts.launch.configuration`.
