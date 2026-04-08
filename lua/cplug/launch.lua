local M = {}

local function launch_path(ctx)
  return vim.fs.joinpath(ctx.cwd, ctx.config.launch.path)
end

local function request_kind_label(request_kind)
  if request_kind == "attach" then
    return "attach"
  end

  return "launch"
end

local function missing_launch_error(path, request_kind)
  if request_kind == "attach" then
    return ("No attach config found at `%s`"):format(path)
  end

  return ("No launch config found at `%s`"):format(path)
end

local function read_file(path)
  if vim.fn.filereadable(path) == 0 then
    return nil, missing_launch_error(path)
  end

  return table.concat(vim.fn.readfile(path), "\n")
end

local function decode(json_text, path)
  local ok, decoded = pcall(vim.json.decode, json_text)

  if not ok then
    return nil, ("Failed to parse `%s` as JSON: %s"):format(path, decoded)
  end

  if type(decoded) ~= "table" then
    return nil, ("Launch config `%s` did not decode to a JSON object"):format(path)
  end

  if type(decoded.configurations) ~= "table" or vim.tbl_isempty(decoded.configurations) then
    return nil, ("Launch config `%s` does not contain any configurations"):format(path)
  end

  return decoded
end

function M.path(ctx)
  return launch_path(ctx)
end

local function write_launch_file(path, launch_config)
  local dir = vim.fs.dirname(path)

  if dir and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local ok, encoded = pcall(vim.json.encode, launch_config)

  if not ok then
    return nil, ("Failed to encode launch config for `%s`: %s"):format(path, encoded)
  end

  local write_ok = vim.fn.writefile({ encoded }, path)

  if write_ok ~= 0 then
    return nil, ("Failed to write launch config to `%s`"):format(path)
  end

  return {
    path = path,
    raw = launch_config,
  }
end

local function choose_generator(backend, request_kind)
  if request_kind == "attach" then
    return backend.default_attach_config
  end

  return backend.default_launch_config
end

local function should_generate(ctx, path, request_kind)
  local mode = ctx.config.launch.on_missing

  if mode == "always" then
    return true
  end

  if mode == "never" then
    return false
  end

  if mode ~= "prompt" then
    return false, ("Unsupported `launch.on_missing` mode `%s`"):format(mode)
  end

  local choice = vim.fn.confirm(
    ("Generate a minimal %s config at `%s`?"):format(request_kind_label(request_kind), path),
    "&Generate\n&Cancel",
    1
  )

  return choice == 1
end

local function generate_template(ctx, backend, project, build_result, request_kind, opts)
  opts = opts or {}
  local generator = choose_generator(backend, request_kind)

  if type(generator) ~= "function" then
    return nil, missing_launch_error(launch_path(ctx), request_kind)
  end

  local path = launch_path(ctx)
  local should_write = true
  local decision_err

  if not opts.force then
    should_write, decision_err = should_generate(ctx, path, request_kind)
  end

  if decision_err then
    return nil, decision_err
  end

  if not should_write then
    return nil, missing_launch_error(path, request_kind)
  end

  local ok, launch_config = pcall(generator, ctx, project, build_result)

  if not ok then
    return nil, ("backend `%s` failed to generate a %s config: %s"):format(
      backend.id,
      request_kind_label(request_kind),
      launch_config
    )
  end

  if type(launch_config) ~= "table" then
    return nil, ("backend `%s` returned an invalid %s config template"):format(
      backend.id,
      request_kind_label(request_kind)
    )
  end

  return launch_config
end

local function generate(ctx, backend, project, build_result, request_kind)
  local path = launch_path(ctx)
  local launch_config, generate_err = generate_template(ctx, backend, project, build_result, request_kind)

  if not launch_config then
    return nil, generate_err
  end

  return write_launch_file(path, launch_config)
end

local function merge_generated_config(existing_data, generated_config)
  local merged = vim.deepcopy(existing_data.raw)

  merged.version = merged.version or generated_config.version or "0.2.0"
  merged.configurations = merged.configurations or {}

  for _, generated in ipairs(generated_config.configurations or {}) do
    local replaced = false

    for index, existing in ipairs(merged.configurations) do
      if existing.name == generated.name then
        merged.configurations[index] = generated
        replaced = true
        break
      end
    end

    if not replaced then
      table.insert(merged.configurations, generated)
    end
  end

  return merged
end

function M.read(ctx)
  local path = launch_path(ctx)
  local json_text, read_err = read_file(path)

  if not json_text then
    return nil, read_err
  end

  local decoded, decode_err = decode(json_text, path)

  if not decoded then
    return nil, decode_err
  end

  return {
    path = path,
    raw = decoded,
  }
end

function M.write_generated(ctx, backend, project, build_result, opts)
  opts = opts or {}

  local request_kind = opts.request_kind
  local path = launch_path(ctx)
  local generated_config, generate_err = generate_template(ctx, backend, project, build_result, request_kind, {
    force = true,
  })

  if not generated_config then
    return nil, generate_err
  end

  local existing_data = M.read(ctx)

  if not existing_data then
    return write_launch_file(path, generated_config)
  end

  local merged = merge_generated_config(existing_data, generated_config)

  return write_launch_file(path, merged)
end

function M.select(ctx, launch_data, opts)
  opts = opts or {}
  local request_kind = opts.request_kind
  local selected_name = ctx.config.launch.configuration

  if selected_name then
    for _, configuration in ipairs(launch_data.raw.configurations) do
      if configuration.name == selected_name then
        if request_kind == "attach" and configuration.request ~= "attach" then
          return nil, ("Launch configuration `%s` in `%s` is not an attach configuration"):format(
            selected_name,
            launch_data.path
          )
        end

        return configuration
      end
    end

    return nil, ("Launch configuration `%s` was not found in `%s`"):format(selected_name, launch_data.path)
  end

  if request_kind == "attach" then
    for _, configuration in ipairs(launch_data.raw.configurations) do
      if configuration.request == "attach" then
        return configuration
      end
    end

    return nil, ("No attach configuration was found in `%s`"):format(launch_data.path)
  end

  return launch_data.raw.configurations[1]
end

function M.resolve(ctx, backend, project, build_result, opts)
  opts = opts or {}
  local request_kind = opts.request_kind
  local launch_data, read_err = M.read(ctx)

  if not launch_data then
    launch_data, read_err = generate(ctx, backend, project, build_result, request_kind)

    if not launch_data then
      return nil, read_err
    end
  end

  local configuration, select_err = M.select(ctx, launch_data, opts)

  if not configuration then
    return nil, select_err
  end

  return {
    configuration = configuration,
    path = launch_data.path,
    raw = launch_data.raw,
  }
end

return M
