local M = {}

local LOW_LEVEL_ADAPTERS = {
  lldb = true,
  codelldb = true,
  cppdbg = true,
  gdb = true,
}

local MANAGED_DAPUI_LAYOUTS = {
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
      { id = "repl", size = 0.5 },
      { id = "console", size = 0.5 },
    },
    position = "bottom",
    size = 10,
  },
  {
    elements = {
      { id = "disassembly", size = 0.5 },
      { id = "repl", size = 0.25 },
      { id = "console", size = 0.25 },
    },
    position = "bottom",
    size = 16,
  },
}

local state = {
  active_layouts = nil,
  current_session = nil,
  dapui_configured = false,
  dapui_managed = false,
  disassembly_configured = false,
  disassembly_warned = false,
  managed_has_disassembly = false,
}

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

local function require_optional_dependency(module_name)
  local ok, module = pcall(require, module_name)

  if ok then
    return module
  end

  return nil
end

local function notify(message, level)
  vim.notify(message, level, { title = "cplug.nvim" })
end

local function build_run_config(ctx, launch_config)
  local run_config = vim.deepcopy(launch_config.configuration)

  if run_config.cwd == nil then
    run_config.cwd = ctx.cwd
  end

  return run_config
end

local function is_low_level_run_config(run_config)
  return LOW_LEVEL_ADAPTERS[run_config.type] == true
end

local function build_managed_layouts(include_disassembly)
  local layouts = {
    vim.deepcopy(MANAGED_DAPUI_LAYOUTS[1]),
    vim.deepcopy(MANAGED_DAPUI_LAYOUTS[2]),
  }

  if include_disassembly then
    layouts[3] = vim.deepcopy(MANAGED_DAPUI_LAYOUTS[3])
  end

  return layouts
end

local function configure_managed_dapui(dapui, include_disassembly)
  if type(dapui.setup) ~= "function" then
    return
  end

  if state.dapui_configured and state.managed_has_disassembly == include_disassembly then
    return
  end

  dapui.setup({
    layouts = build_managed_layouts(include_disassembly),
  })

  state.dapui_managed = true
  state.dapui_configured = true
  state.managed_has_disassembly = include_disassembly
end

local function resolve_active_layouts(low_level)
  if low_level and state.managed_has_disassembly then
    return { 1, 3 }
  end

  return { 1, 2 }
end

local function open_managed_layouts(dapui, layouts)
  if type(dapui.open) ~= "function" then
    return nil, "Installed `dapui` module does not support `open`"
  end

  if type(dapui.close) == "function" then
    dapui.close()
  end

  for _, layout in ipairs(layouts) do
    dapui.open({ layout = layout, reset = true })
  end

  return true
end

local function are_active_layouts_open(layouts)
  local ok, windows = pcall(require, "dapui.windows")

  if not ok or type(windows.layouts) ~= "table" then
    return nil
  end

  for _, layout in ipairs(layouts) do
    local win_layout = windows.layouts[layout]

    if win_layout and type(win_layout.is_open) == "function" and win_layout:is_open() then
      return true
    end
  end

  return false
end

local function toggle_managed_layouts(dapui, layouts)
  local open = are_active_layouts_open(layouts)

  if open == nil then
    if type(dapui.toggle) ~= "function" then
      return nil, "Installed `dapui` module does not support `toggle`"
    end

    dapui.toggle({})
    return true
  end

  if open then
    if type(dapui.close) ~= "function" then
      return nil, "Installed `dapui` module does not support `close`"
    end

    dapui.close()
    return true
  end

  return open_managed_layouts(dapui, layouts)
end

local function ensure_disassembly(config, low_level)
  if not config.dap.disassembly.enabled then
    return false
  end

  local disassembly = require_optional_dependency("dap-disasm")

  if not disassembly then
    if low_level and not state.disassembly_warned then
      notify(
        "Low-level debug UI is running without disassembly; install `Jorenar/nvim-dap-disasm` or disable `dap.disassembly.enabled`.",
        vim.log.levels.WARN
      )
      state.disassembly_warned = true
    end

    return false
  end

  if not state.disassembly_configured and type(disassembly.setup) == "function" then
    disassembly.setup({
      dapview_register = false,
    })
    state.disassembly_configured = true
  end

  return true
end

local function ensure_ui(config, low_level)
  local dapui, dapui_err = require_dependency("dapui", "rcarriga/nvim-dap-ui")

  if not dapui then
    return nil, dapui_err
  end

  local disassembly_enabled = ensure_disassembly(config, low_level)
  local manage_ui_layout = config.dap.manage_ui_layout ~= false

  state.dapui_managed = manage_ui_layout

  if manage_ui_layout then
    configure_managed_dapui(dapui, disassembly_enabled)
    state.active_layouts = resolve_active_layouts(low_level)
  else
    state.dapui_configured = false
    state.active_layouts = nil
  end

  return dapui, nil, disassembly_enabled
end

function M.start(ctx, launch_config)
  local dap, dap_err = require_dependency("dap", "mfussenegger/nvim-dap")

  if not dap then
    return nil, dap_err
  end

  local run_config = build_run_config(ctx, launch_config)
  local low_level = is_low_level_run_config(run_config)
  local dapui
  local disassembly_enabled = false

  state.current_session = {
    config = ctx.config,
    low_level = low_level,
  }

  if ctx.config.dap.open_ui then
    dapui, dap_err, disassembly_enabled = ensure_ui(ctx.config, low_level)

    if not dapui then
      return nil, dap_err
    end

    if state.dapui_managed and state.active_layouts then
      local opened, open_err = open_managed_layouts(dapui, state.active_layouts)

      if not opened then
        return nil, open_err
      end
    else
      if type(dapui.open) ~= "function" then
        return nil, "Installed `dapui` module does not support `open`"
      end

      dapui.open()
    end
  end

  dap.run(run_config)

  return {
    adapter = run_config.type,
    disassembly = low_level and disassembly_enabled,
    low_level = low_level,
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

function M.toggle_ui()
  local session = state.current_session
  local dapui
  local dapui_err

  if session then
    dapui, dapui_err = ensure_ui(session.config, session.low_level)
  else
    dapui, dapui_err = require_dependency("dapui", "rcarriga/nvim-dap-ui")
  end

  if not dapui then
    return nil, dapui_err
  end

  if state.dapui_managed and state.active_layouts then
    return toggle_managed_layouts(dapui, state.active_layouts)
  end

  if type(dapui.toggle) ~= "function" then
    return nil, "Installed `dapui` module does not support `toggle`"
  end

  dapui.toggle({})

  return true
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
