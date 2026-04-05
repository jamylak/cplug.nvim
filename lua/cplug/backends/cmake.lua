local M = {
  id = "cmake",
}

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function is_executable(path)
  return vim.fn.executable(path) == 1 and vim.fn.isdirectory(path) == 0
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

local function find_binaries(build_dir)
  local preferred = {}
  local fallback = {}

  local function scan(dir)
    local fs = vim.uv.fs_scandir(dir)

    if not fs then
      return
    end

    while true do
      local name, kind = vim.uv.fs_scandir_next(fs)

      if not name then
        break
      end

      local path = vim.fs.joinpath(dir, name)

      if kind == "directory" then
        scan(path)
      elseif kind == "file" and is_executable(path) then
        if not path:find("/CMakeFiles/", 1, true) then
          table.insert(preferred, path)
        else
          table.insert(fallback, path)
        end
      end
    end
  end

  if vim.uv.fs_scandir(build_dir) then
    scan(build_dir)
  end

  table.sort(preferred)
  table.sort(fallback)

  return not vim.tbl_isempty(preferred) and preferred or fallback
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
      local binaries = find_binaries(project.build_dir)

      return {
        kind = project.kind,
        mode = "debug",
        build_dir = project.build_dir,
        binaries = binaries,
      }
    end

    return nil, ("CMake build failed: %s"):format(build_err)
  end

  return nil, ("CMake configure failed: %s"):format(configure_err)
end

function M.default_launch_config(_, _, build_result)
  if vim.tbl_isempty(build_result.binaries or {}) then
    error("no built executable was found in the CMake build directory")
  end

  local program = build_result.binaries[1]
  local name = ("Debug %s"):format(path_basename(program))

  return {
    version = "0.2.0",
    configurations = {
      {
        name = name,
        type = "lldb",
        request = "launch",
        program = program,
        cwd = "${workspaceFolder}",
      },
    },
  }
end

return M
