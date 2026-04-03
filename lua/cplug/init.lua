local config = require("cplug.config")
local commands = require("cplug.commands")

local M = {}

M._config = config.defaults()

function M.setup(opts)
  M._config = config.resolve(opts)
  commands.setup(M._config)

  return M._config
end

function M.config()
  return vim.deepcopy(M._config)
end

function M.compile_and_debug()
  vim.notify(
    "cplug.nvim: compile/debug orchestration is not implemented yet",
    vim.log.levels.INFO,
    { title = "cplug.nvim" }
  )
end

return M
