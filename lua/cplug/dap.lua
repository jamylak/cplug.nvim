local M = {}

local LOW_LEVEL_ADAPTERS = {
  lldb = true,
  codelldb = true,
  cppdbg = true,
  gdb = true,
}

local MANAGED_DAPUI_PRESET_ORDER = {
  "standard",
  "native",
  "code_repl",
  "stack_focus",
  "repl_only",
}

local MANAGED_DAPUI_PRESETS = {
  standard = {
    description = "Standard debug view with scopes and a bottom REPL",
    build = function()
      return {
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
            { id = "repl", size = 1 },
          },
          position = "bottom",
          size = 10,
        },
      }
    end,
  },
  native = {
    description = "Native debugging view with disassembly and REPL",
    build = function(include_disassembly)
      local bottom_elements = {
        { id = "repl", size = 1 },
      }

      if include_disassembly then
        bottom_elements = {
          { id = "disassembly", size = 0.7 },
          { id = "repl", size = 0.3 },
        }
      end

      return {
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
          elements = bottom_elements,
          position = "bottom",
          size = include_disassembly and 16 or 10,
        },
      }
    end,
  },
  code_repl = {
    description = "Code-focused view with only a bottom REPL",
    build = function()
      return {
        {
          elements = {
            { id = "repl", size = 1 },
          },
          position = "bottom",
          size = 14,
        },
      }
    end,
  },
  stack_focus = {
    description = "Stack-focused view for crash and call-flow debugging",
    build = function()
      return {
        {
          elements = {
            { id = "stacks", size = 0.45 },
            { id = "scopes", size = 0.35 },
            { id = "breakpoints", size = 0.2 },
          },
          position = "left",
          size = 44,
        },
        {
          elements = {
            { id = "repl", size = 1 },
          },
          position = "bottom",
          size = 10,
        },
      }
    end,
  },
  repl_only = {
    description = "REPL-only view for command-driven debugging",
    build = function()
      return {
        {
          elements = {
            { id = "repl", size = 1 },
          },
          position = "right",
          size = 90,
        },
      }
    end,
  },
}

local state = {
  active_layouts = nil,
  current_layout_name = nil,
  current_session = nil,
  dapui_configured = false,
  dapui_managed = false,
  disassembly_configured = false,
  disassembly_warned = false,
  layout_override = nil,
  managed_layout_has_disassembly = false,
  managed_layout_name = nil,
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

local function find_executable(candidates)
  for _, candidate in ipairs(candidates) do
    local resolved = vim.fn.exepath(candidate)

    if type(resolved) == "string" and resolved ~= "" then
      return resolved
    end
  end

  return nil
end

local function maybe_register_auto_adapter(config, dap, adapter_name)
  if type(dap.adapters) ~= "table" then
    return
  end

  if dap.adapters[adapter_name] ~= nil then
    return
  end

  if config.dap.auto_adapter ~= adapter_name then
    return
  end

  if adapter_name == "lldb" then
    local command = find_executable({ "lldb-dap", "codelldb", "lldb-vscode" })

    if command == nil then
      return
    end

    dap.adapters.lldb = {
      type = "executable",
      command = command,
      name = "lldb",
    }
  end
end

local function ensure_adapter_registered(dap, adapter_name)
  local adapters = dap.adapters

  if type(adapters) ~= "table" then
    return nil, "Installed `dap` module does not expose `adapters`"
  end

  if adapters[adapter_name] == nil then
    return nil, ("Config references missing adapter `%s`"):format(adapter_name)
  end

  return true
end

local function notify(message, level)
  vim.notify(message, level, { title = "cplug.nvim" })
end

local function resolve_managed_pick_process(run_config)
  if run_config.pid ~= "${command:pickProcess}" then
    return run_config
  end

  run_config.pid = function()
    local process_picker = require("cplug.process_picker")
    return process_picker.pick_process({
      prompt = "Select process: ",
    })
  end

  return run_config
end

local function build_run_config(ctx, launch_config)
  local run_config = vim.deepcopy(launch_config.configuration)

  if run_config.cwd == nil then
    run_config.cwd = ctx.cwd
  end

  return resolve_managed_pick_process(run_config)
end

local function is_low_level_run_config(run_config)
  return LOW_LEVEL_ADAPTERS[run_config.type] == true
end

local function managed_layout_names(include_auto)
  local names = {}

  if include_auto then
    table.insert(names, "auto")
  end

  for _, name in ipairs(MANAGED_DAPUI_PRESET_ORDER) do
    table.insert(names, name)
  end

  return names
end

local function resolve_layout_name(config, low_level)
  local requested = state.layout_override or config.dap.layout or "auto"

  if requested == "auto" then
    return low_level and "native" or "standard"
  end

  if MANAGED_DAPUI_PRESETS[requested] then
    return requested
  end

  return nil, ("Unknown DAP layout `%s`"):format(requested)
end

local function build_managed_layouts(layout_name, include_disassembly)
  local preset = MANAGED_DAPUI_PRESETS[layout_name]

  if not preset then
    return nil, ("Unknown DAP layout `%s`"):format(layout_name)
  end

  local layouts = preset.build(include_disassembly)

  if type(layouts) ~= "table" or vim.tbl_isempty(layouts) then
    return nil, ("DAP layout `%s` returned no layouts"):format(layout_name)
  end

  return layouts
end

local function resolve_active_layouts(layouts)
  local active = {}

  for index = 1, #layouts do
    table.insert(active, index)
  end

  return active
end

local function configure_managed_dapui(dapui, layout_name, layouts, include_disassembly)
  if type(dapui.setup) ~= "function" then
    return
  end

  if
    state.dapui_configured
    and state.managed_layout_name == layout_name
    and state.managed_layout_has_disassembly == include_disassembly
  then
    return
  end

  dapui.setup({
    layouts = layouts,
  })

  state.dapui_managed = true
  state.dapui_configured = true
  state.managed_layout_has_disassembly = include_disassembly
  state.managed_layout_name = layout_name
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
    local layout_name, layout_err = resolve_layout_name(config, low_level)

    if not layout_name then
      return nil, layout_err
    end

    local include_disassembly = disassembly_enabled and layout_name == "native"
    local layouts, layouts_err = build_managed_layouts(layout_name, include_disassembly)

    if not layouts then
      return nil, layouts_err
    end

    configure_managed_dapui(dapui, layout_name, layouts, include_disassembly)
    state.active_layouts = resolve_active_layouts(layouts)
    state.current_layout_name = layout_name
  else
    state.dapui_configured = false
    state.active_layouts = nil
    state.current_layout_name = nil
  end

  return dapui, nil, disassembly_enabled
end

local function apply_selected_layout(config)
  if config.dap.manage_ui_layout == false then
    return true
  end

  if not require_optional_dependency("dapui") then
    return true
  end

  local low_level = state.current_session and state.current_session.low_level or false
  local dapui, dapui_err = ensure_ui(config, low_level)

  if not dapui then
    return nil, dapui_err
  end

  if state.active_layouts then
    return open_managed_layouts(dapui, state.active_layouts)
  end

  return true
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
  local adapter_ok
  local adapter_err

  state.current_session = {
    config = ctx.config,
    low_level = low_level,
  }

  maybe_register_auto_adapter(ctx.config, dap, run_config.type)
  adapter_ok, adapter_err = ensure_adapter_registered(dap, run_config.type)

  if not adapter_ok then
    return nil, adapter_err
  end

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
    layout = state.current_layout_name,
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

function M.layout_names(include_auto)
  return managed_layout_names(include_auto)
end

function M.current_layout_name(config)
  local low_level = state.current_session and state.current_session.low_level or false
  local layout_name = resolve_layout_name(config, low_level)

  if not layout_name then
    return nil
  end

  return layout_name
end

function M.select_layout(config)
  local layout_picker = require("cplug.layout_picker")
  local entries = {
    {
      name = "auto",
      description = "Follow adapter type: standard for most sessions, native for low-level adapters",
      ordinal = "auto follow adapter type standard native automatic",
    },
  }

  for _, name in ipairs(MANAGED_DAPUI_PRESET_ORDER) do
    entries[#entries + 1] = {
      name = name,
      description = MANAGED_DAPUI_PRESETS[name].description,
      ordinal = ("%s %s"):format(name, MANAGED_DAPUI_PRESETS[name].description),
    }
  end

  return layout_picker.open({
    entries = entries,
    active_name = state.layout_override or config.dap.layout or "auto",
    on_select = function(name)
      local ok, err = M.set_layout(config, name)

      if not ok and err then
        notify(err, vim.log.levels.ERROR)
      end
    end,
  })
end

function M.set_layout(config, name)
  local requested = name or "auto"

  if requested ~= "auto" and not MANAGED_DAPUI_PRESETS[requested] then
    return nil, ("Unknown DAP layout `%s`"):format(requested)
  end

  state.layout_override = requested

  local applied, apply_err = apply_selected_layout(config)

  if not applied then
    return nil, apply_err
  end

  if requested == "auto" then
    notify("DAP UI layout set to `auto`", vim.log.levels.INFO)
  else
    notify(("DAP UI layout set to `%s`"):format(requested), vim.log.levels.INFO)
  end

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

function M.run_to_cursor()
  return run_action("run_to_cursor")
end

function M.restart()
  return run_action("restart")
end

function M.evaluate()
  local widgets, widgets_err = require_dependency("dap.ui.widgets", "mfussenegger/nvim-dap")

  if not widgets then
    return nil, widgets_err
  end

  if type(widgets.hover) ~= "function" then
    return nil, "Installed `dap.ui.widgets` module does not support `hover`"
  end

  widgets.hover()

  return true
end

return M
