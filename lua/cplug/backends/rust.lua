local M = {
  id = "rust",
}

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function path_basename(path)
  return vim.fs.basename(path)
end

local function run_command(args, cwd)
  local result = vim.system(args, { cwd = cwd, text = true }):wait()

  if result.code ~= 0 then
    local output = result.stderr ~= "" and result.stderr or result.stdout
    return nil, output ~= "" and output or ("Command failed: %s"):format(table.concat(args, " "))
  end

  return result
end

local function target_is_binary(target)
  if type(target.kind) ~= "table" then
    return false
  end

  for _, kind in ipairs(target.kind) do
    if kind == "bin" then
      return true
    end
  end

  return false
end

local function read_metadata(project)
  local result, metadata_err = run_command({
    "cargo",
    "metadata",
    "--no-deps",
    "--format-version",
    "1",
  }, project.root)

  if not result then
    return nil, ("Cargo metadata failed: %s"):format(metadata_err)
  end

  local ok, metadata = pcall(vim.json.decode, result.stdout)

  if not ok or type(metadata) ~= "table" then
    return nil, "Failed to parse cargo metadata output"
  end

  return metadata
end

local function resolve_binary(metadata, project)
  if type(metadata.packages) ~= "table" then
    return nil, "Cargo metadata did not include any packages"
  end

  for _, package in ipairs(metadata.packages) do
    if package.manifest_path == project.cargo_toml and type(package.targets) == "table" then
      for _, target in ipairs(package.targets) do
        if target_is_binary(target) then
          return {
            name = target.name,
            path = vim.fs.joinpath(project.root, "target", "debug", target.name),
          }
        end
      end
    end
  end

  return nil, "No binary target was found in Cargo metadata"
end

function M.detect(ctx)
  local cargo_toml = vim.fs.joinpath(ctx.cwd, "Cargo.toml")

  if not file_exists(cargo_toml) then
    return nil
  end

  return {
    kind = "rust",
    root = ctx.cwd,
    cargo_toml = cargo_toml,
  }
end

function M.build(_, project)
  local _, build_err = run_command({ "cargo", "build" }, project.root)

  if build_err then
    return nil, ("Cargo build failed: %s"):format(build_err)
  end

  local metadata, metadata_err = read_metadata(project)

  if not metadata then
    return nil, metadata_err
  end

  local binary, binary_err = resolve_binary(metadata, project)

  if not binary then
    return nil, binary_err
  end

  if vim.fn.filereadable(binary.path) == 0 then
    return nil, ("Expected built binary at `%s`"):format(binary.path)
  end

  return {
    kind = project.kind,
    mode = "debug",
    binary = binary.path,
    binary_name = binary.name,
  }
end

function M.default_launch_config(_, _, build_result)
  return {
    version = "0.2.0",
    configurations = {
      {
        name = ("Debug %s"):format(path_basename(build_result.binary)),
        type = "lldb",
        request = "launch",
        program = build_result.binary,
        cwd = "${workspaceFolder}",
      },
    },
  }
end

return M
