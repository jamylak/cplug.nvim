local M = {}

function M.workspace_path(ctx, path)
  if type(path) ~= "string" or path == "" then
    return path
  end

  if path:find("^%${") then
    return path
  end

  local root = ctx and ctx.cwd

  if type(root) ~= "string" or root == "" then
    return path
  end

  if path == root then
    return "${workspaceFolder}"
  end

  local prefix = root

  if prefix:sub(-1) ~= "/" then
    prefix = prefix .. "/"
  end

  if path:sub(1, #prefix) ~= prefix then
    return path
  end

  return ("${workspaceFolder}/%s"):format(path:sub(#prefix + 1))
end

return M
