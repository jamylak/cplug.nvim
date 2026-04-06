local backend = require("cplug.backends.cmake")

local M = {}

local function build_context(config)
  return {
    config = config,
    cwd = vim.fn.getcwd(),
  }
end

local function notify(message, level)
  vim.notify(message, level, { title = "cplug.nvim" })
end

local function run_step(method, ...)
  local ok, result, secondary = pcall(backend[method], ...)

  if not ok then
    return nil, ("backend `%s` failed during `%s`: %s"):format(backend.id, method, result)
  end

  if result == nil then
    return nil, secondary or ("backend `%s` returned no result for `%s`"):format(backend.id, method)
  end

  return result, secondary
end

local function resolve_project(ctx)
  local project = backend.detect(ctx)

  if not project then
    local err = ("No CMake project detected in `%s`"):format(ctx.cwd)
    notify(err, vim.log.levels.WARN)
    return nil, err
  end

  if project.needs_scaffold and backend.scaffold then
    local scaffolded_project, scaffold_err = run_step("scaffold", ctx, project)

    if not scaffolded_project then
      notify(scaffold_err, vim.log.levels.ERROR)
      return nil, scaffold_err
    end

    project = scaffolded_project
  end

  return project
end

local function build_project(ctx)
  local project, project_err = resolve_project(ctx)

  if not project then
    return nil, project_err
  end

  local build_result, build_err = run_step("build", ctx, project)

  if not build_result then
    notify(build_err, vim.log.levels.ERROR)
    return nil, build_err
  end

  return {
    backend = backend.id,
    build = build_result,
    project = project,
  }
end

function M.configure(config)
  local ctx = build_context(config)
  local project, project_err = resolve_project(ctx)

  if not project then
    return nil, project_err
  end

  local configure_result, configure_err = run_step("configure", ctx, project)

  if not configure_result then
    notify(configure_err, vim.log.levels.ERROR)
    return nil, configure_err
  end

  notify(("Configured `%s` project in `%s`"):format(backend.id, configure_result.build_dir), vim.log.levels.INFO)

  return {
    backend = backend.id,
    configure = configure_result,
    project = project,
  }
end

function M.build_once(config)
  local ctx = build_context(config)
  local result, build_err = build_project(ctx)

  if not result then
    return nil, build_err
  end

  notify(("Built `%s` project in `%s`"):format(backend.id, result.build.build_dir), vim.log.levels.INFO)

  return result
end

function M.build_and_run(config)
  local ctx = build_context(config)
  local result, build_err = build_project(ctx)

  if not result then
    return nil, build_err
  end

  local binaries = result.build.binaries or {}

  if vim.tbl_isempty(binaries) then
    local err = "No built executable was found after the CMake build"
    notify(err, vim.log.levels.ERROR)
    return nil, err
  end

  local program = binaries[1]
  local run_result = vim.system({ program }, {
    cwd = result.project.root,
    text = true,
  }):wait()

  if run_result.code ~= 0 then
    local output = run_result.stderr ~= "" and run_result.stderr or run_result.stdout
    local err = output ~= "" and output or ("Program failed: %s"):format(program)
    notify(err, vim.log.levels.ERROR)
    return nil, err
  end

  notify(("Built and ran `%s`"):format(program), vim.log.levels.INFO)

  result.run = {
    program = program,
    stdout = run_result.stdout,
    stderr = run_result.stderr,
    code = run_result.code,
  }

  return result
end

return M
