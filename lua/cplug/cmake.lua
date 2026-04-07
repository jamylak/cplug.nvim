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

local function open_terminal_window()
  vim.cmd("botright split")
  vim.cmd("enew")

  local win_id = vim.api.nvim_get_current_win()
  local buf_id = vim.api.nvim_get_current_buf()

  vim.bo[buf_id].bufhidden = "wipe"
  vim.bo[buf_id].swapfile = false

  return win_id, buf_id
end

local function close_terminal_view(buf_id, win_id)
  if vim.api.nvim_win_is_valid(win_id) and vim.api.nvim_win_get_buf(win_id) == buf_id then
    vim.api.nvim_win_close(win_id, true)
  end

  if vim.api.nvim_buf_is_valid(buf_id) then
    vim.api.nvim_buf_delete(buf_id, { force = true })
  end
end

local function focus_terminal_window(win_id, buf_id)
  if not vim.api.nvim_win_is_valid(win_id) or not vim.api.nvim_buf_is_valid(buf_id) then
    return
  end

  vim.api.nvim_set_current_win(win_id)
  vim.api.nvim_win_set_cursor(win_id, { vim.api.nvim_buf_line_count(buf_id), 0 })

  if vim.tbl_isempty(vim.api.nvim_list_uis()) then
    return
  end

  vim.cmd("startinsert")
end

local function run_in_terminal(result, cmd, opts)
  opts = opts or {}
  local win_id, buf_id = open_terminal_window()
  local result_key = opts.result_key or "run"
  local terminal_result = result[result_key] or {}
  local job_id = vim.fn.termopen(cmd, {
    cwd = opts.cwd or result.project.root,
    on_exit = function(_, code)
      if opts.close_on_success and code == 0 then
        vim.schedule(function()
          close_terminal_view(buf_id, win_id)
        end)
      end

      if opts.on_exit then
        vim.schedule(function()
          opts.on_exit(code, terminal_result, result)
        end)
      end
    end,
  })

  if job_id <= 0 then
    local err = ("Failed to start `%s` in a terminal buffer"):format(cmd[1])
    notify(err, vim.log.levels.ERROR)
    return nil, err
  end

  focus_terminal_window(win_id, buf_id)

  local command = table.concat(cmd, " ")
  terminal_result = vim.tbl_extend("force", terminal_result, {
    command = command,
    job_id = job_id,
    terminal_buf = buf_id,
    terminal_win = win_id,
  })

  result[result_key] = terminal_result

  return result
end

local function prepare_build_result(config)
  local ctx = build_context(config)
  local project, project_err = resolve_project(ctx)

  if not project then
    return nil, nil, project_err
  end

  local configure_result, configure_err = run_step("configure", ctx, project)

  if not configure_result then
    notify(configure_err, vim.log.levels.ERROR)
    return nil, nil, configure_err
  end

  local build_args, build_args_err = run_step("build_command", ctx, project)

  if not build_args then
    notify(build_args_err, vim.log.levels.ERROR)
    return nil, nil, build_args_err
  end

  return {
    backend = backend.id,
    configure = configure_result,
    build = {
      kind = project.kind,
      mode = "debug",
      build_dir = project.build_dir,
    },
    project = project,
  }, build_args
end

function M.configure(config)
  local ctx = build_context(config)
  local project, project_err = resolve_project(ctx)

  if not project then
    return nil, project_err
  end

  local configure_args, configure_args_err = run_step("configure_command", ctx, project)

  if not configure_args then
    notify(configure_args_err, vim.log.levels.ERROR)
    return nil, configure_args_err
  end

  local result = {
    backend = backend.id,
    configure = {
      kind = project.kind,
      mode = "debug",
      build_dir = project.build_dir,
      configured = true,
    },
    project = project,
  }

  return run_in_terminal(result, configure_args, {
    close_on_success = not config.c_family.keep_configure_terminal_open,
    result_key = "configure",
  })
end

function M.build_once(config)
  local result, build_args, build_err = prepare_build_result(config)

  if not result then
    return nil, build_err
  end

  return run_in_terminal(result, build_args, {
    close_on_success = not config.c_family.keep_build_terminal_open,
    result_key = "build",
  })
end

function M.build_and_run(config)
  local result, build_args, build_err = prepare_build_result(config)

  if not result then
    return nil, build_err
  end

  return run_in_terminal(result, build_args, {
    close_on_success = not config.c_family.keep_build_terminal_open,
    result_key = "build",
    on_exit = function(code)
      if code ~= 0 then
        return
      end

      vim.defer_fn(function()
        local binary_result, binary_err = run_step("resolve_binaries", build_context(config), result.project)

        if not binary_result then
          notify(binary_err, vim.log.levels.ERROR)
          return
        end

        result.build = vim.tbl_extend("force", result.build or {}, binary_result)

        local run_result, run_err = run_in_terminal(result, { binary_result.binaries[1] })

        if not run_result then
          notify(run_err, vim.log.levels.ERROR)
        end
      end, 0)
    end,
  })
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

  return run_in_terminal(result, { binary_result.binaries[1] })
end

return M
