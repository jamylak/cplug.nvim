local M = {}

local ns = vim.api.nvim_create_namespace("cplug.process_picker")

local state = {
  active = false,
  prompt = "Process> ",
  prompt_buf = nil,
  prompt_win = nil,
  list_buf = nil,
  list_win = nil,
  entries = {},
  filtered = {},
  selected = 1,
  query = "",
  on_select = nil,
  on_cancel = nil,
  installed = false,
  original_pick_process = nil,
}

local function entry_from_process(proc)
  local command = vim.trim(proc.name or "")
  local first = command:match("^[^%s]+") or command
  local basename = vim.fs.basename(first)

  if basename == "" then
    basename = command ~= "" and command or ("pid %d"):format(proc.pid)
  end

  return {
    pid = proc.pid,
    name = basename,
    description = ("pid=%d  %s"):format(proc.pid, command ~= "" and command or "[unknown process]"),
    ordinal = table.concat({
      tostring(proc.pid),
      basename,
      command,
    }, " "),
  }
end

local function filter_entries(query)
  if query == "" then
    return vim.deepcopy(state.entries)
  end

  local lookup = {}
  local values = {}

  for _, entry in ipairs(state.entries) do
    lookup[entry.ordinal] = entry
    values[#values + 1] = entry.ordinal
  end

  local ok, matched = pcall(vim.fn.matchfuzzy, values, query)

  if not ok then
    matched = {}
    local lower_query = query:lower()

    for _, entry in ipairs(state.entries) do
      if entry.ordinal:lower():find(lower_query, 1, true) then
        matched[#matched + 1] = entry.ordinal
      end
    end
  end

  local filtered = {}

  for _, ordinal in ipairs(matched) do
    filtered[#filtered + 1] = lookup[ordinal]
  end

  return filtered
end

local function read_query()
  if not state.prompt_buf or not vim.api.nvim_buf_is_valid(state.prompt_buf) then
    return ""
  end

  local line = vim.api.nvim_buf_get_lines(state.prompt_buf, 0, 1, false)[1] or ""

  if vim.startswith(line, state.prompt) then
    return line:sub(#state.prompt + 1)
  end

  return line
end

local function set_prompt_text(text)
  if not state.prompt_buf or not vim.api.nvim_buf_is_valid(state.prompt_buf) then
    return
  end

  local full_text = state.prompt .. text
  vim.api.nvim_buf_set_lines(state.prompt_buf, 0, -1, false, { full_text })

  if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
    vim.api.nvim_win_set_cursor(state.prompt_win, { 1, #full_text })
  end
end

local function render()
  if not state.list_buf or not vim.api.nvim_buf_is_valid(state.list_buf) then
    return
  end

  state.filtered = filter_entries(state.query)

  if #state.filtered == 0 then
    state.selected = 0
  elseif state.selected < 1 then
    state.selected = 1
  elseif state.selected > #state.filtered then
    state.selected = #state.filtered
  end

  local lines = {}

  if #state.filtered == 0 then
    lines[1] = "  No matching processes"
  else
    for index, entry in ipairs(state.filtered) do
      local prefix = index == state.selected and "> " or "  "
      lines[index] = prefix .. entry.name .. "  " .. entry.description
    end
  end

  vim.bo[state.list_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.list_buf, 0, -1, false, lines)
  vim.bo[state.list_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.list_buf, ns, 0, -1)

  if #state.filtered == 0 then
    vim.api.nvim_buf_add_highlight(state.list_buf, ns, "Comment", 0, 0, -1)
    return
  end

  for index, entry in ipairs(state.filtered) do
    local line_index = index - 1

    if index == state.selected then
      vim.api.nvim_buf_add_highlight(state.list_buf, ns, "Visual", line_index, 0, -1)
    end

    local name_col_start = 2
    local name_col_end = name_col_start + #entry.name
    local desc_col_start = name_col_end + 2

    vim.api.nvim_buf_add_highlight(state.list_buf, ns, "Directory", line_index, name_col_start, name_col_end)
    vim.api.nvim_buf_add_highlight(state.list_buf, ns, "Comment", line_index, desc_col_start, -1)
  end
end

local function close(selected_pid)
  if not state.active then
    return
  end

  state.active = false

  local prompt_win = state.prompt_win
  local list_win = state.list_win
  local prompt_buf = state.prompt_buf
  local list_buf = state.list_buf
  local on_select = state.on_select
  local on_cancel = state.on_cancel

  state.prompt_buf = nil
  state.prompt_win = nil
  state.list_buf = nil
  state.list_win = nil
  state.entries = {}
  state.filtered = {}
  state.selected = 1
  state.query = ""
  state.on_select = nil
  state.on_cancel = nil

  if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
    vim.api.nvim_win_close(prompt_win, true)
  end

  if list_win and vim.api.nvim_win_is_valid(list_win) then
    vim.api.nvim_win_close(list_win, true)
  end

  if prompt_buf and vim.api.nvim_buf_is_valid(prompt_buf) then
    vim.api.nvim_buf_delete(prompt_buf, { force = true })
  end

  if list_buf and vim.api.nvim_buf_is_valid(list_buf) then
    vim.api.nvim_buf_delete(list_buf, { force = true })
  end

  if selected_pid ~= nil then
    if type(on_select) == "function" then
      on_select(selected_pid)
    end
  elseif type(on_cancel) == "function" then
    on_cancel()
  end
end

local function move_selection(delta)
  if #state.filtered == 0 then
    return
  end

  state.selected = state.selected + delta

  if state.selected < 1 then
    state.selected = #state.filtered
  elseif state.selected > #state.filtered then
    state.selected = 1
  end

  render()
end

local function select_current()
  local entry = state.filtered[state.selected]

  if not entry then
    return
  end

  close(entry.pid)
end

local function update_query()
  state.query = read_query()
  state.selected = 1
  render()
end

local function create_window(buf, opts)
  local win = vim.api.nvim_open_win(buf, opts.enter, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = opts.title,
    title_pos = "center",
    width = opts.width,
    height = opts.height,
    row = opts.row,
    col = opts.col,
  })

  vim.wo[win].winblend = 0
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:Title"

  return win
end

function M.open(opts)
  opts = opts or {}

  if state.active then
    if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
      vim.api.nvim_set_current_win(state.prompt_win)
      vim.cmd("startinsert")
    end
    return true
  end

  state.entries = vim.deepcopy(opts.entries or {})
  state.query = opts.initial_query or ""
  state.filtered = filter_entries(state.query)
  state.selected = #state.filtered > 0 and 1 or 0
  state.active = true
  state.on_select = opts.on_select
  state.on_cancel = opts.on_cancel

  local width = math.min(math.max(64, math.floor(vim.o.columns * 0.62)), 112)
  local max_list_height = math.max(4, vim.o.lines - 8)
  local list_height = math.min(math.max(#state.entries, 1), math.max(8, math.floor(vim.o.lines * 0.36)), max_list_height)
  local total_height = list_height + 5
  local row = math.max(1, math.floor((vim.o.lines - total_height) / 2) - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  state.prompt_buf = vim.api.nvim_create_buf(false, true)
  state.list_buf = vim.api.nvim_create_buf(false, true)

  vim.bo[state.prompt_buf].buftype = "prompt"
  vim.bo[state.prompt_buf].bufhidden = "wipe"
  vim.bo[state.prompt_buf].filetype = "cplug_process_picker"
  vim.fn.prompt_setprompt(state.prompt_buf, state.prompt)

  vim.bo[state.list_buf].bufhidden = "wipe"
  vim.bo[state.list_buf].filetype = "cplug_process_picker"
  vim.bo[state.list_buf].modifiable = false

  state.prompt_win = create_window(state.prompt_buf, {
    enter = true,
    title = "Cplug Processes",
    width = width,
    height = 1,
    row = row,
    col = col,
  })

  state.list_win = create_window(state.list_buf, {
    enter = false,
    title = "Type to filter  Enter: select  Esc: cancel",
    width = width,
    height = list_height,
    row = row + 3,
    col = col,
  })

  set_prompt_text(state.query)
  render()

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = state.prompt_buf,
      silent = true,
      nowait = true,
      desc = desc,
    })
  end

  map({ "i", "n" }, "<Esc>", function()
    close(nil)
  end, "Close process picker")
  map({ "i", "n" }, "<C-c>", function()
    close(nil)
  end, "Close process picker")
  map("n", "q", function()
    close(nil)
  end, "Close process picker")
  map({ "i", "n" }, "<Down>", function()
    move_selection(1)
  end, "Next process")
  map({ "i", "n" }, "<C-n>", function()
    move_selection(1)
  end, "Next process")
  map({ "i", "n" }, "<Tab>", function()
    move_selection(1)
  end, "Next process")
  map({ "i", "n" }, "<Up>", function()
    move_selection(-1)
  end, "Previous process")
  map({ "i", "n" }, "<C-p>", function()
    move_selection(-1)
  end, "Previous process")
  map({ "i", "n" }, "<S-Tab>", function()
    move_selection(-1)
  end, "Previous process")
  map({ "i", "n" }, "<CR>", select_current, "Select process")
  map("i", "<C-w>", "<C-S-w>", "Delete word")

  local group = vim.api.nvim_create_augroup("cplug.process_picker." .. state.prompt_buf, { clear = true })

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    group = group,
    buffer = state.prompt_buf,
    callback = update_query,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(state.prompt_win),
    callback = function()
      vim.schedule(function()
        close(nil)
      end)
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(state.list_win),
    callback = function()
      vim.schedule(function()
        close(nil)
      end)
    end,
  })

  vim.cmd("startinsert")

  return true
end

function M.pick_process(opts)
  local ok_dap_utils, dap_utils = pcall(require, "dap.utils")

  if not ok_dap_utils or type(dap_utils.get_processes) ~= "function" then
    local fallback = state.original_pick_process

    if type(fallback) == "function" then
      return fallback(opts)
    end

    return require("dap").ABORT
  end

  local procs = dap_utils.get_processes(opts)
  local entries = {}

  for _, proc in ipairs(procs) do
    entries[#entries + 1] = entry_from_process(proc)
  end

  table.sort(entries, function(left, right)
    if left.name == right.name then
      return left.pid < right.pid
    end

    return left.name < right.name
  end)

  local co, ismain = coroutine.running()

  if not co or ismain then
    local fallback = state.original_pick_process

    if type(fallback) == "function" then
      return fallback(opts)
    end

    return require("dap").ABORT
  end

  return coroutine.create(function(parent)
    local completed = false

    local function finish(value)
      if completed then
        return
      end

      completed = true
      vim.schedule(function()
        coroutine.resume(parent, value)
      end)
    end

    M.open({
      entries = entries,
      initial_query = type(opts) == "table" and opts.filter or "",
      on_select = finish,
      on_cancel = function()
        finish(require("dap").ABORT)
      end,
    })
  end)
end

function M.install()
  local ok, dap_utils = pcall(require, "dap.utils")

  if not ok or type(dap_utils) ~= "table" then
    return false
  end

  if dap_utils.pick_process == M.pick_process then
    state.installed = true
    return true
  end

  if not state.original_pick_process and type(dap_utils.pick_process) == "function" then
    state.original_pick_process = dap_utils.pick_process
  end

  dap_utils.pick_process = M.pick_process
  state.installed = true

  return true
end

return M
