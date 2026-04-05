local M = {}

local function check_dependency(module_name, help)
  local ok = pcall(require, module_name)

  if ok then
    vim.health.ok(("Found `%s`"):format(module_name))
    return
  end

  vim.health.warn(("Missing `%s`"):format(module_name), {
    "Install the dependency before using cplug.nvim end-to-end.",
    help,
  })
end

function M.check()
  vim.health.start("cplug.nvim")
  vim.health.info("Launch resolution and DAP startup are available. Language coverage is still limited.")

  check_dependency("dap", "Expected `mfussenegger/nvim-dap` to be available on `runtimepath`.")
  check_dependency("dapui", "Expected `rcarriga/nvim-dap-ui` to be available on `runtimepath`.")
end

return M
