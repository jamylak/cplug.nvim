# cplug.nvim

`cplug.nvim` aims to make `<leader>c` the compile-and-debug entrypoint for small local projects.

This first iteration only establishes the plugin skeleton:

- a public `setup()` API
- a `:CPlugCompileDebug` user command
- optional default keymaps
- a `:checkhealth cplug` healthcheck

The compile/build/debug orchestration described in [PLAN.md](./PLAN.md) will land in later iterations.

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
