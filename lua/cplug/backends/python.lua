local M = {
  id = "python",
}

local function has_file(path)
  return vim.fn.filereadable(path) == 1
end

local function is_executable(path)
  return vim.fn.executable(path) == 1 and vim.fn.isdirectory(path) == 0
end

local ignored_dirs = {
  [".git"] = true,
  [".venv"] = true,
  ["venv"] = true,
  ["__pycache__"] = true,
  ["build"] = true,
  ["target"] = true,
}

local function find_python_files(cwd)
  local files = {}

  local function scan(dir)
    local fs = vim.uv.fs_scandir(dir)

    if not fs then
      return
    end

    while true do
      local name, kind = vim.uv.fs_scandir_next(fs)

      if not name then
        break
      end

      local path = vim.fs.joinpath(dir, name)

      if kind == "directory" then
        if not ignored_dirs[name] then
          scan(path)
        end
      elseif kind == "file" and name:sub(-3) == ".py" then
        table.insert(files, path)
      end
    end
  end

  scan(cwd)
  table.sort(files)

  return files
end

local function resolve_interpreter(ctx)
  local configured = ctx.config.python.interpreter

  if configured then
    return configured
  end

  local candidates = {
    vim.fs.joinpath(ctx.cwd, ".venv", "bin", "python"),
    vim.fs.joinpath(ctx.cwd, "venv", "bin", "python"),
    vim.fs.joinpath(ctx.cwd, ".venv", "Scripts", "python.exe"),
    vim.fs.joinpath(ctx.cwd, "venv", "Scripts", "python.exe"),
  }

  for _, candidate in ipairs(candidates) do
    if is_executable(candidate) then
      return candidate
    end
  end

  local python3 = vim.fn.exepath("python3")

  if python3 ~= "" then
    return python3
  end

  local python = vim.fn.exepath("python")

  if python ~= "" then
    return python
  end
end

local function resolve_program(project)
  if #project.files == 1 then
    return project.files[1]
  end

  return "${file}"
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

function M.default_launch_config(ctx, project)
  local configuration = {
    name = "Debug current file",
    type = "python",
    request = "launch",
    program = resolve_program(project),
    console = "integratedTerminal",
  }

  local interpreter = resolve_interpreter(ctx)

  if interpreter then
    configuration.python = interpreter
  end

  return {
    version = "0.2.0",
    configurations = { configuration },
  }
end

function M.default_attach_config()
  return {
    version = "0.2.0",
    configurations = {
      {
        name = "Attach to Python server",
        type = "python",
        request = "attach",
        connect = {
          host = "127.0.0.1",
          port = 5678,
        },
      },
    },
  }
end

return M
