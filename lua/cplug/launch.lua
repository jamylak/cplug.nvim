local M = {}

local picker_override

local function launch_path(ctx)
  return vim.fs.joinpath(ctx.cwd, ctx.config.launch.path)
end

local function request_kind_label(request_kind)
  if request_kind == "attach" then
    return "attach"
  end

  return "launch"
end

local function is_attach_request(request)
  return request == "attach"
end

local function is_launch_request(request)
  return request == nil or request == "launch"
end

local function is_compatible_configuration(configuration, request_kind)
  local request = configuration.request

  if request_kind == "attach" then
    return is_attach_request(request)
  end

  return is_launch_request(request)
end

local function mismatch_error(configuration_name, path, request_kind)
  if request_kind == "attach" then
    return ("Launch configuration `%s` in `%s` is not an attach configuration"):format(configuration_name, path)
  end

  return ("Launch configuration `%s` in `%s` is not a launch configuration"):format(configuration_name, path)
end

local function missing_compatible_error(path, request_kind)
  if request_kind == "attach" then
    return ("No attach configuration was found in `%s`"):format(path)
  end

  return ("No launch configuration was found in `%s`"):format(path)
end

local function configuration_entries(configurations)
  local entries = {}

  for _, configuration in ipairs(configurations) do
    local details = {}
    local request = configuration.request or "launch"

    details[#details + 1] = ("request=%s"):format(request)

    if type(configuration.type) == "string" and configuration.type ~= "" then
      details[#details + 1] = ("type=%s"):format(configuration.type)
    end

    if type(configuration.program) == "string" and configuration.program ~= "" then
      details[#details + 1] = configuration.program
    elseif type(configuration.module) == "string" and configuration.module ~= "" then
      details[#details + 1] = ("module=%s"):format(configuration.module)
    elseif type(configuration.pid) == "string" and configuration.pid ~= "" then
      details[#details + 1] = ("pid=%s"):format(configuration.pid)
    elseif type(configuration.connect) == "table" then
      local host = configuration.connect.host or "127.0.0.1"
      local port = configuration.connect.port or "?"
      details[#details + 1] = ("connect=%s:%s"):format(host, port)
    end

    entries[#entries + 1] = {
      name = configuration.name,
      description = table.concat(details, "  "),
      ordinal = table.concat({
        configuration.name or "",
        request,
        configuration.type or "",
        configuration.program or "",
        configuration.module or "",
      }, " "),
      configuration = configuration,
    }
  end

  return entries
end

local function pick_configuration(configurations)
  local picker = picker_override

  if picker == nil then
    picker = require("cplug.launch_config_picker").pick
  end

  return picker({
    entries = configuration_entries(configurations),
  })
end

local function pick_configuration_async(configurations, callback)
  if picker_override ~= nil then
    local entry, pick_err = pick_configuration(configurations)
    callback(entry, pick_err)
    return
  end

  require("cplug.launch_config_picker").pick_async({
    entries = configuration_entries(configurations),
    on_select = function(entry)
      callback(entry, nil)
    end,
    on_cancel = function()
      callback(nil, "Launch configuration selection cancelled")
    end,
  })
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

local function is_array(value)
  local count = 0

  for key, _ in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end

    count = count + 1
  end

  return count == #value
end

local function sorted_keys(value)
  local keys = vim.tbl_keys(value)
  local priority = {
    version = 1,
    configurations = 2,
    name = 10,
    type = 11,
    request = 12,
    program = 13,
    cwd = 14,
    console = 15,
    redirectOutput = 16,
    python = 17,
    pid = 18,
    connect = 19,
    host = 20,
    port = 21,
  }

  table.sort(keys, function(left, right)
    local left_priority = priority[left] or 100
    local right_priority = priority[right] or 100

    if left_priority ~= right_priority then
      return left_priority < right_priority
    end

    return tostring(left) < tostring(right)
  end)

  return keys
end

local function encode_json_pretty(value, indent_level)
  indent_level = indent_level or 0

  if type(value) == "table" then
    local current_indent = string.rep("  ", indent_level)
    local child_indent = string.rep("  ", indent_level + 1)

    if vim.tbl_isempty(value) then
      return is_array(value) and "[]" or "{}"
    end

    local lines = {}

    if is_array(value) then
      for index = 1, #value do
        table.insert(lines, child_indent .. encode_json_pretty(value[index], indent_level + 1))
      end

      return "[\n" .. table.concat(lines, ",\n") .. "\n" .. current_indent .. "]"
    end

    for _, key in ipairs(sorted_keys(value)) do
      local encoded_key = vim.json.encode(tostring(key))
      local encoded_value = encode_json_pretty(value[key], indent_level + 1)
      table.insert(lines, ("%s%s: %s"):format(child_indent, encoded_key, encoded_value))
    end

    return "{\n" .. table.concat(lines, ",\n") .. "\n" .. current_indent .. "}"
  end

  local ok, encoded = pcall(vim.json.encode, value)

  if not ok then
    error(encoded)
  end

  return encoded
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

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function write_launch_file(path, launch_config)
  local dir = vim.fs.dirname(path)

  if dir and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local ok, encoded = pcall(encode_json_pretty, launch_config)

  if not ok then
    return nil, ("Failed to encode launch config for `%s`: %s"):format(path, encoded)
  end

  local write_ok = vim.fn.writefile(vim.split(encoded, "\n", { plain = true }), path)

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

  if not file_exists(path) then
    return write_launch_file(path, generated_config)
  end

  local existing_data, read_err = M.read(ctx)

  if not existing_data then
    return nil, read_err
  end

  local merged = merge_generated_config(existing_data, generated_config)

  return write_launch_file(path, merged)
end

local function compatible_configurations(launch_data, request_kind)
  local compatible = {}

  for _, configuration in ipairs(launch_data.raw.configurations) do
    if is_compatible_configuration(configuration, request_kind) then
      compatible[#compatible + 1] = configuration
    end
  end

  return compatible
end

function M.compatible_configurations(launch_data, opts)
  opts = opts or {}
  return compatible_configurations(launch_data, opts.request_kind)
end

function M.set_picker(picker)
  picker_override = picker
end

function M.select(ctx, launch_data, opts)
  opts = opts or {}
  local request_kind = opts.request_kind
  local selected_name = ctx.config.launch.configuration
  local select_mode = ctx.config.launch.select or "auto"

  if selected_name then
    for _, configuration in ipairs(launch_data.raw.configurations) do
      if configuration.name == selected_name then
        if not is_compatible_configuration(configuration, request_kind) then
          return nil, mismatch_error(selected_name, launch_data.path, request_kind)
        end

        return configuration
      end
    end

    return nil, ("Launch configuration `%s` was not found in `%s`"):format(selected_name, launch_data.path)
  end

  local compatible = compatible_configurations(launch_data, request_kind)

  if vim.tbl_isempty(compatible) then
    return nil, missing_compatible_error(launch_data.path, request_kind)
  end

  if select_mode == "first" then
    return compatible[1]
  end

  if select_mode == "auto" then
    if #compatible == 1 then
      return compatible[1]
    end

    local entry, pick_err = pick_configuration(compatible)

    if not entry then
      return nil, pick_err
    end

    return entry.configuration
  end

  if select_mode == "picker" then
    if #compatible == 1 then
      return compatible[1]
    end

    local entry, pick_err = pick_configuration(compatible)

    if not entry then
      return nil, pick_err
    end

    return entry.configuration
  end

  return nil, ("Unsupported `launch.select` mode `%s`"):format(select_mode)
end

function M.select_interactive(ctx, launch_data, opts, callback)
  opts = opts or {}
  local request_kind = opts.request_kind
  local selected_name = ctx.config.launch.configuration
  local select_mode = ctx.config.launch.select or "auto"

  if selected_name or select_mode == "first" or picker_override ~= nil then
    return M.select(ctx, launch_data, opts)
  end

  local compatible = compatible_configurations(launch_data, request_kind)

  if vim.tbl_isempty(compatible) then
    return nil, missing_compatible_error(launch_data.path, request_kind)
  end

  if select_mode == "auto" or select_mode == "picker" then
    if #compatible == 1 then
      return compatible[1]
    end

    pick_configuration_async(compatible, function(entry, pick_err)
      if not entry then
        callback(nil, pick_err)
        return
      end

      callback(entry.configuration, nil)
    end)

    return nil, nil, true
  end

  return nil, ("Unsupported `launch.select` mode `%s`"):format(select_mode)
end

function M.resolve(ctx, backend, project, build_result, opts)
  opts = opts or {}
  local request_kind = opts.request_kind
  local path = launch_path(ctx)
  local launch_data, read_err

  if file_exists(path) then
    launch_data, read_err = M.read(ctx)

    if not launch_data then
      return nil, read_err
    end
  else
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

function M.resolve_interactive(ctx, backend, project, build_result, opts, callback)
  opts = opts or {}
  local request_kind = opts.request_kind
  local path = launch_path(ctx)
  local launch_data, read_err

  if file_exists(path) then
    launch_data, read_err = M.read(ctx)

    if not launch_data then
      return nil, read_err
    end
  else
    launch_data, read_err = generate(ctx, backend, project, build_result, request_kind)

    if not launch_data then
      return nil, read_err
    end
  end

  local configuration, select_err, pending = M.select_interactive(ctx, launch_data, opts, function(selected, callback_err)
    if not selected then
      callback(nil, callback_err)
      return
    end

    callback({
      configuration = selected,
      path = launch_data.path,
      raw = launch_data.raw,
    }, nil)
  end)

  if pending then
    return nil, nil, true
  end

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
