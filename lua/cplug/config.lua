local M = {}

local defaults = {
  create_commands = true,
  default_keymaps = true,
  keymaps = {
    compile_debug = "<leader>c",
  },
  launch = {
    path = ".vscode/launch.json",
    configuration = nil,
    on_missing = "prompt",
  },
}

function M.defaults()
  return vim.deepcopy(defaults)
end

function M.resolve(opts)
  return vim.tbl_deep_extend("force", M.defaults(), opts or {})
end

return M
