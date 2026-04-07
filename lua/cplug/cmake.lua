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

local function open_terminal_window()
  vim.cmd("botright split")
  vim.cmd("enew")

  local win_id = vim.api.nvim_get_current_win()
  local buf_id = vim.api.nvim_get_current_buf()

  vim.bo[buf_id].bufhidden = "wipe"
  vim.bo[buf_id].swapfile = false

  return win_id, buf_id
end

local function run_in_terminal(result, program)
  local win_id, buf_id = open_terminal_window()
  local job_id = vim.fn.termopen({ program }, {
    cwd = result.project.root,
  })

  if job_id <= 0 then
    local err = ("Failed to start `%s` in a terminal buffer"):format(program)
    notify(err, vim.log.levels.ERROR)
    return nil, err
  end

  vim.api.nvim_set_current_win(win_id)
  vim.api.nvim_win_set_cursor(win_id, { vim.api.nvim_buf_line_count(buf_id), 0 })

  if not vim.tbl_isempty(vim.api.nvim_list_uis()) then
    vim.cmd("startinsert")
  end

  result.run = {
    program = program,
    job_id = job_id,
    terminal_buf = buf_id,
    terminal_win = win_id,
  }

  return result
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
  local run_result, run_err = run_in_terminal(result, program)

  if not run_result then
    return nil, run_err
  end

  return run_result
end

function M.run(config)
  local ctx = build_context(config)
  local project, project_err = resolve_project(ctx)

  if not project then
    return nil, project_err
  end

  local binary_result, binary_err = run_step("resolve_binaries", ctx, project)

  if not binary_result then
    notify(binary_err, vim.log.levels.ERROR)
    return nil, binary_err
  end

  local result = {
    backend = backend.id,
    build = binary_result,
    project = project,
  }

  return run_in_terminal(result, binary_result.binaries[1])
end

return M
