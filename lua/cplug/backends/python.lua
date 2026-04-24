local M = {
  id = "python",
}

local function has_file(path)
  return vim.fn.filereadable(path) == 1
end

local function is_executable(path)
  return vim.fn.executable(path) == 1 and vim.fn.isdirectory(path) == 0
end

local function run_command(args, cwd, env)
  local opts = {
    cwd = cwd,
    text = true,
  }

  if env and not vim.tbl_isempty(env) then
    opts.env = env
  end

  local result = vim.system(args, opts):wait()

  if result.code ~= 0 then
    local output = result.stderr ~= "" and result.stderr or result.stdout
    return nil, output ~= "" and output or ("Command failed: %s"):format(table.concat(args, " "))
  end

  return result
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

local function configured_interpreter(ctx)
  local configured = ctx.config.python.interpreter

  if configured then
    return configured
  end
end

local function env_python_candidates(ctx)
  local env_dir = ctx.config.python.env_dir or ".venv"
  local env_path = vim.fs.joinpath(ctx.cwd, env_dir)

  return {
    vim.fs.joinpath(env_path, "bin", "python"),
    vim.fs.joinpath(env_path, "Scripts", "python.exe"),
    vim.fs.joinpath(ctx.cwd, ".venv", "bin", "python"),
    vim.fs.joinpath(ctx.cwd, "venv", "bin", "python"),
    vim.fs.joinpath(ctx.cwd, ".venv", "Scripts", "python.exe"),
    vim.fs.joinpath(ctx.cwd, "venv", "Scripts", "python.exe"),
  }
end

local function resolve_env_interpreter(ctx)
  for _, candidate in ipairs(env_python_candidates(ctx)) do
    if is_executable(candidate) then
      return candidate
    end
  end
end

local function resolve_system_interpreter()
  local python3 = vim.fn.exepath("python3")

  if python3 ~= "" then
    return python3
  end

  local python = vim.fn.exepath("python")

  if python ~= "" then
    return python
  end
end

local function resolve_interpreter(ctx)
  return configured_interpreter(ctx) or resolve_env_interpreter(ctx) or resolve_system_interpreter()
end

local function has_debugpy(python)
  if not python then
    return false
  end

  local ok, system = pcall(vim.system, {
    python,
    "-c",
    "import debugpy",
  }, { text = true })

  if not ok then
    return false
  end

  local result = system:wait()

  return result.code == 0
end

local function uv_args(ctx, ...)
  local uv = ctx.config.python.uv or {}
  local args = { uv.command or "uv" }

  if uv.native_tls then
    table.insert(args, "--native-tls")
  end

  for _, extra in ipairs(uv.extra_args or {}) do
    table.insert(args, extra)
  end

  for _, arg in ipairs({ ... }) do
    table.insert(args, arg)
  end

  return args
end

local function bootstrap_with_uv(ctx, env_path)
  local uv = ctx.config.python.uv or {}

  if vim.fn.exepath(uv.command or "uv") == "" then
    return nil, nil
  end

  local env = uv.env or {}
  local _, venv_err = run_command(uv_args(ctx, "venv", env_path), ctx.cwd, env)

  if venv_err then
    return nil, ("uv venv failed: %s"):format(venv_err)
  end

  local interpreter = resolve_env_interpreter(ctx)

  if not interpreter then
    return nil, ("uv created `%s`, but no Python executable was found in it"):format(env_path)
  end

  local _, install_err = run_command(
    uv_args(ctx, "pip", "install", "--python", interpreter, ctx.config.python.debugpy_package or "debugpy"),
    ctx.cwd,
    env
  )

  if install_err then
    return nil, ("uv pip install failed: %s"):format(install_err)
  end

  return interpreter
end

local function bootstrap_with_venv(ctx, env_path)
  local base_python = resolve_system_interpreter()

  if not base_python then
    return nil, "No `python3` or `python` executable was found on PATH"
  end

  local _, venv_err = run_command({ base_python, "-m", "venv", env_path }, ctx.cwd)

  if venv_err then
    return nil, ("python venv failed: %s"):format(venv_err)
  end

  local interpreter = resolve_env_interpreter(ctx)

  if not interpreter then
    return nil, ("Python created `%s`, but no Python executable was found in it"):format(env_path)
  end

  local _, install_err = run_command({
    interpreter,
    "-m",
    "pip",
    "install",
    ctx.config.python.debugpy_package or "debugpy",
  }, ctx.cwd)

  if install_err then
    return nil, ("pip install failed: %s"):format(install_err)
  end

  return interpreter
end

local function ensure_debugpy(ctx)
  local configured = configured_interpreter(ctx)
  local interpreter = configured or resolve_env_interpreter(ctx)

  if not ctx.config.python.bootstrap_debugpy then
    local resolved = resolve_interpreter(ctx)

    return resolved, {
      bootstrapped = false,
      debugpy = has_debugpy(resolved),
      reason = "disabled",
    }
  end

  if configured then
    return configured, {
      bootstrapped = false,
      debugpy = nil,
      reason = "configured interpreter is not mutated",
    }
  end

  if interpreter and has_debugpy(interpreter) then
    return interpreter, {
      bootstrapped = false,
      debugpy = true,
    }
  end

  local env_path = vim.fs.joinpath(ctx.cwd, ctx.config.python.env_dir or ".venv")
  local bootstrapped, bootstrap_err = bootstrap_with_uv(ctx, env_path)

  if bootstrap_err then
    return nil, bootstrap_err
  end

  if not bootstrapped then
    bootstrapped, bootstrap_err = bootstrap_with_venv(ctx, env_path)
  end

  if not bootstrapped then
    return nil, bootstrap_err
  end

  if not has_debugpy(bootstrapped) then
    return nil, ("Installed `%s`, but `%s -c 'import debugpy'` still failed"):format(
      ctx.config.python.debugpy_package or "debugpy",
      bootstrapped
    )
  end

  return bootstrapped, {
    bootstrapped = true,
    debugpy = true,
    env_dir = env_path,
  }
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

function M.build(ctx, project)
  local interpreter, debugpy = ensure_debugpy(ctx)

  if not interpreter then
    return nil, debugpy
  end

  return {
    kind = project.kind,
    mode = "debug",
    skipped = true,
    reason = "python projects do not require a compile step",
    interpreter = interpreter,
    debugpy = debugpy,
  }
end

function M.default_launch_config(ctx, project, build_result)
  local configuration = {
    name = "Debug current file",
    type = "python",
    request = "launch",
    program = resolve_program(project),
    console = ctx.config.python.console,
    redirectOutput = ctx.config.python.redirect_output,
  }

  local interpreter = build_result and build_result.interpreter or resolve_interpreter(ctx)

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
