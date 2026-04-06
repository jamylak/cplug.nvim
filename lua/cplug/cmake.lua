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

function M.configure(config)
  local ctx = build_context(config)
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

return M
