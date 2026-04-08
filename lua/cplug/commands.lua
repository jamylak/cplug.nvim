local M = {}

local compile_debug_command_name = "CPlugCompileDebug"
local attach_command_name = "CPlugAttach"
local generate_attach_command_name = "CPlugGenerateAttach"
local cmake_configure_command_name = "CPlugCMakeConfigure"
local cmake_build_once_command_name = "CPlugCMakeBuildOnce"
local cmake_build_and_run_command_name = "CPlugCMakeBuildAndRun"
local cmake_run_command_name = "CPlugCMakeRun"
local layout_command_name = "CPlugLayout"

local function create_commands()
  if M.commands_created then
    return
  end

  vim.api.nvim_create_user_command(compile_debug_command_name, function()
    require("cplug").compile_and_debug()
  end, {
    desc = "Compile the current project in debug mode and start debugging",
  })

  vim.api.nvim_create_user_command(attach_command_name, function()
    require("cplug").attach()
  end, {
    desc = "Attach to an existing debug target using the selected attach config",
  })

  vim.api.nvim_create_user_command(generate_attach_command_name, function()
    require("cplug").generate_attach_config()
  end, {
    desc = "Generate or update an attach configuration for the current project",
  })

  vim.api.nvim_create_user_command(cmake_configure_command_name, function()
    require("cplug").cmake_configure()
  end, {
    desc = "Configure the current CMake project in debug mode",
  })

  vim.api.nvim_create_user_command(cmake_build_once_command_name, function()
    require("cplug").cmake_build_once()
  end, {
    desc = "Build the current CMake project once in debug mode",
  })

  vim.api.nvim_create_user_command(cmake_build_and_run_command_name, function()
    require("cplug").cmake_build_and_run()
  end, {
    desc = "Build and run the current CMake project in debug mode",
  })

  vim.api.nvim_create_user_command(cmake_run_command_name, function()
    require("cplug").cmake_run()
  end, {
    desc = "Run the current CMake project without rebuilding",
  })

  vim.api.nvim_create_user_command(layout_command_name, function(opts)
    if opts.args == "" then
      require("cplug").select_layout()
      return
    end

    require("cplug").set_layout(opts.args)
  end, {
    nargs = "?",
    complete = function()
      return require("cplug").layout_names(true)
    end,
    desc = "Switch the managed DAP UI layout or open the layout picker",
  })

  M.commands_created = true
end

local function normalize_keymaps(binding)
  if binding == nil or binding == false then
    return {}
  end

  if type(binding) == "string" then
    return { binding }
  end

  if vim.islist(binding) then
    local keymaps = {}

    for _, lhs in ipairs(binding) do
      if type(lhs) == "string" and lhs ~= "" then
        table.insert(keymaps, lhs)
      end
    end

    return keymaps
  end

  return {}
end

local function set_action_keymaps(binding, rhs, desc)
  for _, lhs in ipairs(normalize_keymaps(binding)) do
    vim.keymap.set("n", lhs, rhs, {
      desc = desc,
    })
  end
end

local function set_keymaps(config)
  if M.keymaps_created or not config.default_keymaps then
    return
  end

  set_action_keymaps(config.keymaps.compile_debug, function()
    require("cplug").compile_and_debug()
  end, "Compile and debug project")

  set_action_keymaps(config.keymaps.toggle_ui, function()
    require("cplug").toggle_ui()
  end, "Toggle debug UI")

  set_action_keymaps(config.keymaps.layout_picker, function()
    require("cplug").select_layout()
  end, "Select debug UI layout")

  set_action_keymaps(config.keymaps.continue, function()
    require("cplug").continue()
  end, "Continue debug session")

  set_action_keymaps(config.keymaps.terminate, function()
    require("cplug").terminate()
  end, "Terminate debug session")

  set_action_keymaps(config.keymaps.step_over, function()
    require("cplug").step_over()
  end, "Step over")

  set_action_keymaps(config.keymaps.step_into, function()
    require("cplug").step_into()
  end, "Step into")

  set_action_keymaps(config.keymaps.step_out, function()
    require("cplug").step_out()
  end, "Step out")

  set_action_keymaps(config.keymaps.toggle_breakpoint, function()
    require("cplug").toggle_breakpoint()
  end, "Toggle breakpoint")

  set_action_keymaps(config.keymaps.run_to_cursor, function()
    require("cplug").run_to_cursor()
  end, "Run to cursor")

  set_action_keymaps(config.keymaps.restart, function()
    require("cplug").restart()
  end, "Restart debug session")

  set_action_keymaps(config.keymaps.evaluate, function()
    require("cplug").evaluate()
  end, "Evaluate expression at cursor")

  M.keymaps_created = true
end

function M.setup(config)
  if config.create_commands then
    create_commands()
  end

  set_keymaps(config)
end

return M
