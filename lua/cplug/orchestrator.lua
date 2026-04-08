local backends = require("cplug.backends")
local dap = require("cplug.dap")
local launch = require("cplug.launch")

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

local function detect_backend(config)
  local ctx = build_context(config)
  local backend, project = backends.detect(ctx)

  if not backend then
    notify(
      ("No supported project detected in `%s`"):format(ctx.cwd),
      vim.log.levels.WARN
    )
    return nil, nil, ctx, "no supported backend detected"
  end

  return backend, project, ctx
end

local function run_step(backend, method, ...)
  local ok, result, secondary = pcall(backend[method], ...)

  if not ok then
    return nil, ("backend `%s` failed during `%s`: %s"):format(backend.id, method, result)
  end

  if result == nil then
    return nil, secondary or ("backend `%s` returned no result for `%s`"):format(backend.id, method)
  end

  return result, secondary
end

function M.run(config)
  local backend, project, ctx, detect_err = detect_backend(config)

  if not backend then
    return nil, detect_err
  end

  if project.needs_scaffold and backend.scaffold then
    local scaffolded_project, scaffold_err = run_step(backend, "scaffold", ctx, project)

    if not scaffolded_project then
      notify(scaffold_err, vim.log.levels.ERROR)
      return nil, scaffold_err
    end

    project = scaffolded_project
  end

  local build_result, build_err = run_step(backend, "build", ctx, project)

  if not build_result then
    notify(build_err, vim.log.levels.ERROR)
    return nil, build_err
  end

  local launch_config, launch_err = launch.resolve(ctx, backend, project, build_result)

  if not launch_config then
    notify(launch_err, vim.log.levels.ERROR)
    return nil, launch_err
  end

  local dap_result, dap_err = dap.start(ctx, launch_config)

  if not dap_result then
    notify(dap_err, vim.log.levels.ERROR)
    return nil, dap_err
  end

  notify(("Started `%s` debug session via `%s`"):format(backend.id, dap_result.adapter), vim.log.levels.INFO)

  return {
    backend = backend.id,
    build = build_result,
    dap = dap_result,
    launch = launch_config,
    project = project,
  }
end

function M.attach(config)
  local backend, project, ctx, detect_err = detect_backend(config)

  if not backend then
    return nil, detect_err
  end

  local launch_config, launch_err = launch.resolve(ctx, backend, project, nil, {
    request_kind = "attach",
  })

  if not launch_config then
    notify(launch_err, vim.log.levels.ERROR)
    return nil, launch_err
  end

  local dap_result, dap_err = dap.start(ctx, launch_config)

  if not dap_result then
    notify(dap_err, vim.log.levels.ERROR)
    return nil, dap_err
  end

  notify(("Attached `%s` debug session via `%s`"):format(backend.id, dap_result.adapter), vim.log.levels.INFO)

  return {
    backend = backend.id,
    dap = dap_result,
    launch = launch_config,
    project = project,
  }
end

function M.generate_attach_config(config)
  local backend, project, ctx, detect_err = detect_backend(config)

  if not backend then
    return nil, detect_err
  end

  local launch_data, launch_err = launch.write_generated(ctx, backend, project, nil, {
    request_kind = "attach",
  })

  if not launch_data then
    notify(launch_err, vim.log.levels.ERROR)
    return nil, launch_err
  end

  notify(("Wrote attach config to `%s`"):format(launch_data.path), vim.log.levels.INFO)

  return {
    backend = backend.id,
    launch = launch_data,
    project = project,
  }
end

return M
