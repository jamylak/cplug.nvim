local M = {}

local command_name = "CPlugCompileDebug"

local function create_command()
  if M.command_created then
    return
  end

  vim.api.nvim_create_user_command(command_name, function()
    require("cplug").compile_and_debug()
  end, {
    desc = "Compile the current project in debug mode and start debugging",
  })

  M.command_created = true
end

local function set_keymaps(config)
  if M.keymaps_created or not config.default_keymaps then
    return
  end

  vim.keymap.set("n", config.keymaps.compile_debug, function()
    require("cplug").compile_and_debug()
  end, {
    desc = "Compile and debug project",
  })

  vim.keymap.set("n", config.keymaps.continue, function()
    require("cplug").continue()
  end, {
    desc = "Continue debug session",
  })

  vim.keymap.set("n", config.keymaps.terminate, function()
    require("cplug").terminate()
  end, {
    desc = "Terminate debug session",
  })

  vim.keymap.set("n", config.keymaps.step_over, function()
    require("cplug").step_over()
  end, {
    desc = "Step over",
  })

  vim.keymap.set("n", config.keymaps.step_into, function()
    require("cplug").step_into()
  end, {
    desc = "Step into",
  })

  vim.keymap.set("n", config.keymaps.step_out, function()
    require("cplug").step_out()
  end, {
    desc = "Step out",
  })

  vim.keymap.set("n", config.keymaps.toggle_breakpoint, function()
    require("cplug").toggle_breakpoint()
  end, {
    desc = "Toggle breakpoint",
  })

  M.keymaps_created = true
end

function M.setup(config)
  if config.create_commands then
    create_command()
  end

  set_keymaps(config)
end

return M
