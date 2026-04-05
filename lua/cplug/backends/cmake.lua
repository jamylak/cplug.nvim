local M = {
  id = "cmake",
}

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function run_command(args, cwd)
  local result = vim.system(args, { cwd = cwd, text = true }):wait()

  if result.code ~= 0 then
    local output = result.stderr ~= "" and result.stderr or result.stdout
    return nil, output ~= "" and output or ("Command failed: %s"):format(table.concat(args, " "))
  end

  return result
end

function M.detect(ctx)
  local cmake_lists = vim.fs.joinpath(ctx.cwd, "CMakeLists.txt")

  if not file_exists(cmake_lists) then
    return nil
  end

  return {
    kind = "cmake",
    root = ctx.cwd,
    cmake_lists = cmake_lists,
    build_dir = vim.fs.joinpath(ctx.cwd, ctx.config.c_family.build_dir),
  }
end

function M.build(_, project)
  local configure_args = {
    "cmake",
    "-S",
    project.root,
    "-B",
    project.build_dir,
    "-DCMAKE_BUILD_TYPE=Debug",
  }

  local _, configure_err = run_command(configure_args, project.root)

  if not configure_err then
    local build_args = {
      "cmake",
      "--build",
      project.build_dir,
      "--config",
      "Debug",
    }

    local _, build_err = run_command(build_args, project.root)

    if not build_err then
      return {
        kind = project.kind,
        mode = "debug",
        build_dir = project.build_dir,
      }
    end

    return nil, ("CMake build failed: %s"):format(build_err)
  end

  return nil, ("CMake configure failed: %s"):format(configure_err)
end

return M
