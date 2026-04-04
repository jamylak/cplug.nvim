local M = {
  id = "python",
}

local function has_file(path)
  return vim.fn.filereadable(path) == 1
end

local function find_python_files(cwd)
  return vim.fn.globpath(cwd, "*.py", false, true)
end

function M.detect(ctx)
  local pyproject = vim.fs.joinpath(ctx.cwd, "pyproject.toml")
  local requirements = vim.fs.joinpath(ctx.cwd, "requirements.txt")
  local python_files = find_python_files(ctx.cwd)

  if not has_file(pyproject) and not has_file(requirements) and vim.tbl_isempty(python_files) then
    return nil
  end

  return {
    kind = "python",
    root = ctx.cwd,
    files = python_files,
    markers = {
      pyproject = has_file(pyproject),
      requirements = has_file(requirements),
    },
  }
end

function M.build(_, project)
  return {
    kind = project.kind,
    mode = "debug",
    skipped = true,
    reason = "python projects do not require a compile step",
  }
end

function M.default_launch_config()
  return {
    version = "0.2.0",
    configurations = {
      {
        name = "Debug current file",
        type = "python",
        request = "launch",
        program = "${file}",
        console = "integratedTerminal",
      },
    },
  }
end

return M
