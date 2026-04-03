local M = {}

local backend_modules = {
  "cplug.backends.python",
}

local required_methods = {
  "detect",
  "build",
}

local function validate(backend)
  vim.validate({
    backend = { backend, "table" },
    id = { backend.id, "string" },
  })

  for _, method in ipairs(required_methods) do
    if type(backend[method]) ~= "function" then
      error(("cplug backend `%s` is missing required method `%s`"):format(backend.id, method))
    end
  end
end

function M.all()
  local backends = {}

  for _, module_name in ipairs(backend_modules) do
    local backend = require(module_name)
    validate(backend)
    table.insert(backends, backend)
  end

  return backends
end

function M.detect(ctx)
  for _, backend in ipairs(M.all()) do
    local project = backend.detect(ctx)

    if project then
      return backend, project
    end
  end
end

return M
