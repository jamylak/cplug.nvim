local M = {
  id = "cmake",
}

local source_languages = {
  c = "C",
  cc = "CXX",
  cpp = "CXX",
  cxx = "CXX",
}

local ignored_dirs = {
  [".git"] = true,
  [".vscode"] = true,
  ["build"] = true,
  ["target"] = true,
  [".venv"] = true,
  ["venv"] = true,
}

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function is_executable(path)
  return vim.fn.executable(path) == 1 and vim.fn.isdirectory(path) == 0
end

local function path_extension(path)
  return path:match("%.([^.]+)$")
end

local function path_basename(path)
  return vim.fs.basename(path)
end

local function sanitize_identifier(name)
  local value = name:gsub("[^%w_]", "_")

  if value == "" then
    value = "cplug_app"
  end

  if value:match("^[0-9]") then
    value = ("_%s"):format(value)
  end

  return value
end

local function relative_path(root, path)
  return path:sub(#root + 2)
end

local function run_command(args, cwd)
  local result = vim.system(args, { cwd = cwd, text = true }):wait()

  if result.code ~= 0 then
    local output = result.stderr ~= "" and result.stderr or result.stdout
    return nil, output ~= "" and output or ("Command failed: %s"):format(table.concat(args, " "))
  end

  return result
end

local function detect_project_languages(source_files)
  local detected = {}

  for _, path in ipairs(source_files) do
    local language = source_languages[path_extension(path)]

    if language then
      detected[language] = true
    end
  end

  local ordered = {}

  if detected.C then
    table.insert(ordered, "C")
  end

  if detected.CXX then
    table.insert(ordered, "CXX")
  end

  return ordered
end

local function repo_is_empty(root, build_dir)
  local fs = vim.uv.fs_scandir(root)
  local build_dir_name = vim.fs.basename(build_dir)

  if not fs then
    return false
  end

  while true do
    local name = vim.uv.fs_scandir_next(fs)

    if not name then
      break
    end

    if not ignored_dirs[name] and name ~= build_dir_name then
      return false
    end
  end

  return true
end

local function find_source_files(root, build_dir)
  local files = {}
  local build_dir_name = vim.fs.basename(build_dir)

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
        if not ignored_dirs[name] and name ~= build_dir_name then
          scan(path)
        end
      elseif kind == "file" and source_languages[path_extension(name)] then
        table.insert(files, path)
      end
    end
  end

  scan(root)
  table.sort(files)

  return files
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

local function render_cmake_lists(project)
  local lines = {
    "cmake_minimum_required(VERSION 3.16)",
    ("project(%s LANGUAGES %s)"):format(project.target_name, table.concat(project.languages, " ")),
    "",
    "set(CMAKE_EXPORT_COMPILE_COMMANDS ON)",
  }

  if vim.list_contains(project.languages, "C") then
    table.insert(lines, "set(CMAKE_C_STANDARD 11)")
    table.insert(lines, "set(CMAKE_C_STANDARD_REQUIRED ON)")
  end

  if vim.list_contains(project.languages, "CXX") then
    table.insert(lines, "set(CMAKE_CXX_STANDARD 17)")
    table.insert(lines, "set(CMAKE_CXX_STANDARD_REQUIRED ON)")
  end

  table.insert(lines, "")
  table.insert(lines, ("add_executable(%s"):format(project.target_name))

  for _, source in ipairs(project.sources) do
    table.insert(lines, ("  %s"):format(relative_path(project.root, source)))
  end

  table.insert(lines, ")")

  return lines
end

local function render_clang_format()
  return {
    "BasedOnStyle: LLVM",
    "IndentWidth: 2",
    "TabWidth: 2",
    "UseTab: Never",
    "ColumnLimit: 100",
  }
end

local function render_starter_source(language)
  if language == "CXX" then
    return {
      "#include <iostream>",
      "",
      "int main() {",
      '  std::cout << "hello" << std::endl;',
      "  return 0;",
      "}",
    }
  end

  return {
    "#include <stdio.h>",
    "",
    "int main(void) {",
    '  puts("hello");',
    "  return 0;",
    "}",
  }
end

local function scaffold_mode(ctx)
  local mode = ctx.config.scaffold.on_missing

  if mode == "always" or mode == "prompt" or mode == "never" then
    return mode
  end

  return nil, ("Unsupported `scaffold.on_missing` mode `%s`"):format(mode)
end

local function resolve_empty_language(ctx, project)
  local mode, mode_err = scaffold_mode(ctx)

  if not mode then
    return nil, mode_err
  end

  if mode == "never" then
    return nil, ("No C/C++ project scaffold found in `%s`"):format(project.root)
  end

  if mode == "prompt" then
    local choice = vim.fn.confirm(
      ("Scaffold an empty project at `%s` as C or C++?"):format(project.root),
      "&C\n&C++\n&Cancel",
      2
    )

    if choice ~= 1 and choice ~= 2 then
      return nil, "CMake scaffolding cancelled"
    end

    return choice == 1 and "C" or "CXX"
  end

  local configured = ctx.config.c_family.empty_project_language

  if configured == "c" then
    return "C"
  end

  if configured == "cpp" then
    return "CXX"
  end

  return nil, ("Unsupported `c_family.empty_project_language` value `%s`"):format(configured)
end

local function should_scaffold(ctx, project)
  local mode, mode_err = scaffold_mode(ctx)

  if not mode then
    return nil, mode_err
  end

  if mode == "always" then
    return true
  end

  if mode == "never" then
    return false, ("No C/C++ project scaffold found in `%s`"):format(project.root)
  end

  local choice = vim.fn.confirm(
    ("Generate minimal C/C++ scaffolding at `%s`?"):format(project.root),
    "&Generate\n&Cancel",
    1
  )

  return choice == 1
end

local function scaffold_empty_project(ctx, project)
  local language, language_err = resolve_empty_language(ctx, project)

  if not language then
    return nil, language_err
  end

  local extension = language == "C" and "c" or "cpp"
  local source_dir = vim.fs.joinpath(project.root, "src")
  local source_path = vim.fs.joinpath(source_dir, ("main.%s"):format(extension))

  if vim.fn.isdirectory(source_dir) == 0 then
    vim.fn.mkdir(source_dir, "p")
  end

  local write_ok = vim.fn.writefile(render_starter_source(language), source_path)

  if write_ok ~= 0 then
    return nil, ("Failed to write `%s`"):format(source_path)
  end

  project.languages = { language }
  project.sources = { source_path }

  return project
end

function M.detect(ctx)
  local cmake_lists = vim.fs.joinpath(ctx.cwd, "CMakeLists.txt")
  local clang_format = vim.fs.joinpath(ctx.cwd, ".clang-format")
  local build_dir = vim.fs.joinpath(ctx.cwd, ctx.config.c_family.build_dir)

  if file_exists(cmake_lists) then
    return {
      kind = "cmake",
      root = ctx.cwd,
      cmake_lists = cmake_lists,
      clang_format = clang_format,
      build_dir = build_dir,
      config = ctx.config.c_family,
    }
  end

  local source_files = find_source_files(ctx.cwd, build_dir)

  if vim.tbl_isempty(source_files) then
    if not repo_is_empty(ctx.cwd, build_dir) then
      return nil
    end

    return {
      kind = "cmake",
      root = ctx.cwd,
      cmake_lists = cmake_lists,
      clang_format = clang_format,
      build_dir = build_dir,
      config = ctx.config.c_family,
      needs_scaffold = true,
      empty_repo = true,
      sources = {},
      target_name = sanitize_identifier(path_basename(ctx.cwd)),
    }
  end

  local languages = detect_project_languages(source_files)

  return {
    kind = "cmake",
    root = ctx.cwd,
    cmake_lists = cmake_lists,
    clang_format = clang_format,
    build_dir = build_dir,
    config = ctx.config.c_family,
    languages = languages,
    needs_scaffold = true,
    sources = source_files,
    target_name = sanitize_identifier(path_basename(ctx.cwd)),
  }
end

function M.scaffold(ctx, project)
  if project.empty_repo then
    local scaffolded_project, scaffold_err = scaffold_empty_project(ctx, project)

    if not scaffolded_project then
      return nil, scaffold_err
    end
  else
    local should_generate, scaffold_err = should_scaffold(ctx, project)

    if scaffold_err then
      return nil, scaffold_err
    end

    if not should_generate then
      return nil, "CMake scaffolding cancelled"
    end
  end

  local write_ok = vim.fn.writefile(render_cmake_lists(project), project.cmake_lists)

  if write_ok ~= 0 then
    return nil, ("Failed to write `%s`"):format(project.cmake_lists)
  end

  if project.config.generate_clang_format and not file_exists(project.clang_format) then
    local clang_format_ok = vim.fn.writefile(render_clang_format(), project.clang_format)

    if clang_format_ok ~= 0 then
      return nil, ("Failed to write `%s`"):format(project.clang_format)
    end
  end

  project.needs_scaffold = nil

  return project
end

function M.configure(_, project)
  local configure_args = {
    "cmake",
    "-S",
    project.root,
    "-B",
    project.build_dir,
    "-DCMAKE_BUILD_TYPE=Debug",
  }

  local _, configure_err = run_command(configure_args, project.root)

  if configure_err then
    return nil, ("CMake configure failed: %s"):format(configure_err)
  end

  return {
    kind = project.kind,
    mode = "debug",
    build_dir = project.build_dir,
    configured = true,
  }
end

function M.build(ctx, project)
  local configure_result, configure_err = M.configure(ctx, project)

  if not configure_result then
    return nil, configure_err
  end

  local build_args = {
    "cmake",
    "--build",
    project.build_dir,
    "--config",
    "Debug",
  }

  local _, build_err = run_command(build_args, project.root)

  if build_err then
    return nil, ("CMake build failed: %s"):format(build_err)
  end

  local binaries = find_binaries(project.build_dir)

  return {
    kind = project.kind,
    mode = "debug",
    build_dir = project.build_dir,
    binaries = binaries,
    configured = configure_result.configured,
  }
end

function M.build_command(_, project)
  return {
    "cmake",
    "--build",
    project.build_dir,
    "--config",
    "Debug",
  }
end

function M.resolve_binaries(_, project)
  local binaries = find_binaries(project.build_dir)

  if vim.tbl_isempty(binaries) then
    return nil, ("No built executable was found in `%s`"):format(project.build_dir)
  end

  return {
    kind = project.kind,
    mode = "debug",
    build_dir = project.build_dir,
    binaries = binaries,
  }
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
