local M = {}

local function require_dependency(module_name, package_name)
  local ok, module = pcall(require, module_name)

  if ok then
    return module
  end

  return nil, ("Missing `%s` dependency; install `%s` before starting a debug session"):format(
    module_name,
    package_name
  )
end

local function build_run_config(ctx, launch_config)
  local run_config = vim.deepcopy(launch_config.configuration)

  if run_config.cwd == nil then
    run_config.cwd = ctx.cwd
  end

  return run_config
end

function M.start(ctx, launch_config)
  local dap, dap_err = require_dependency("dap", "mfussenegger/nvim-dap")

  if not dap then
    return nil, dap_err
  end

  local dapui

  if ctx.config.dap.open_ui then
    dapui, dap_err = require_dependency("dapui", "rcarriga/nvim-dap-ui")

    if not dapui then
      return nil, dap_err
    end

    dapui.open()
  end

  local run_config = build_run_config(ctx, launch_config)

  dap.run(run_config)

  return {
    adapter = run_config.type,
    open_ui = dapui ~= nil,
    run_config = run_config,
  }
end

local function run_action(method, package_name)
  local dap, dap_err = require_dependency("dap", package_name or "mfussenegger/nvim-dap")

  if not dap then
    return nil, dap_err
  end

  if type(dap[method]) ~= "function" then
    return nil, ("Installed `dap` module does not support `%s`"):format(method)
  end

  dap[method]()

  return true
end

function M.continue()
  return run_action("continue")
end

function M.terminate()
  return run_action("terminate")
end

function M.step_over()
  return run_action("step_over")
end

function M.step_into()
  return run_action("step_into")
end

function M.step_out()
  return run_action("step_out")
end

function M.toggle_breakpoint()
  return run_action("toggle_breakpoint")
end

return M
