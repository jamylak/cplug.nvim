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

return M
