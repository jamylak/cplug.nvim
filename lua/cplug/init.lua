local config = require("cplug.config")
local cmake = require("cplug.cmake")
local commands = require("cplug.commands")
local dap = require("cplug.dap")
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

function M.cmake_configure()
  return cmake.configure(M._config)
end

function M.continue()
  return dap.continue()
end

function M.terminate()
  return dap.terminate()
end

function M.step_over()
  return dap.step_over()
end

function M.step_into()
  return dap.step_into()
end

function M.step_out()
  return dap.step_out()
end

function M.toggle_breakpoint()
  return dap.toggle_breakpoint()
end

return M
