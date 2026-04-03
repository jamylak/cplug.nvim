local config = require("cplug.config")
local commands = require("cplug.commands")
local orchestrator = require("cplug.orchestrator")

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
  return orchestrator.run(M._config)
end

return M
