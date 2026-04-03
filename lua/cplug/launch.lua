local M = {}

local function launch_path(ctx)
  return vim.fs.joinpath(ctx.cwd, ctx.config.launch.path)
end

local function read_file(path)
  if vim.fn.filereadable(path) == 0 then
    return nil, ("No launch config found at `%s`"):format(path)
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

function M.select(ctx, launch_data)
  local selected_name = ctx.config.launch.configuration

  if selected_name then
    for _, configuration in ipairs(launch_data.raw.configurations) do
      if configuration.name == selected_name then
        return configuration
      end
    end

    return nil, ("Launch configuration `%s` was not found in `%s`"):format(selected_name, launch_data.path)
  end

  return launch_data.raw.configurations[1]
end

function M.resolve(ctx)
  local launch_data, read_err = M.read(ctx)

  if not launch_data then
    return nil, read_err
  end

  local configuration, select_err = M.select(ctx, launch_data)

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
