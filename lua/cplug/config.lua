local M = {}

local defaults = {
  create_commands = true,
  default_keymaps = true,
  keymaps = {
    compile_debug = "<leader>c",
    toggle_ui = "<leader>gg",
    continue = "<leader>gc",
    terminate = "<leader>gx",
    step_over = "<leader>gn",
    step_into = "<leader>gi",
    step_out = "<leader>go",
    toggle_breakpoint = "<leader>gb",
  },
  launch = {
    path = ".vscode/launch.json",
    configuration = nil,
    on_missing = "prompt",
  },
  scaffold = {
    on_missing = "always",
  },
  dap = {
    open_ui = true,
  },
  c_family = {
    build_dir = "build",
    generate_clang_format = true,
    empty_project_language = "cpp",
  },
  python = {
    interpreter = nil,
  },
}

function M.defaults()
  return vim.deepcopy(defaults)
end

function M.resolve(opts)
  return vim.tbl_deep_extend("force", M.defaults(), opts or {})
end

return M
