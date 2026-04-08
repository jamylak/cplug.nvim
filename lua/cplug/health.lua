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

local function check_runtime_dependency(label, runtime_file, help)
  if #vim.api.nvim_get_runtime_file(runtime_file, false) > 0 then
    vim.health.ok(("Found `%s`"):format(label))
    return
  end

  vim.health.warn(("Missing `%s`"):format(label), {
    "Install the dependency before using the low-level debug layout.",
    help,
  })
end

function M.check()
  vim.health.start("cplug.nvim")
  vim.health.info("Launch resolution and DAP startup are available. Language coverage is still limited.")

  check_dependency("dap", "Expected `mfussenegger/nvim-dap` to be available on `runtimepath`.")
  check_dependency("dapui", "Expected `rcarriga/nvim-dap-ui` to be available on `runtimepath`.")
  check_runtime_dependency(
    "dap-disasm",
    "lua/dap-disasm.lua",
    "Expected `Jorenar/nvim-dap-disasm` to be available on `runtimepath` for low-level disassembly."
  )
end

return M
