local M = {}

if vim.fn.executable("rg") == 0 then
  vim.notify("rg not found — :Grep will not work", vim.log.levels.WARN)
end

local log = require("configs.custom.functions.log")

-- reuse DiagnosticWarn colour for match highlights so it follows the colorscheme
local function set_hl()
  local warn = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false })
  vim.api.nvim_set_hl(0, "QfSearchMatch", { fg = warn.fg, bold = true })
end
set_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })

local hl_ns = vim.api.nvim_create_namespace("search_string_hl")

-- rg is a slow producer (it reads file *contents*, ~1.5s on a big tree), so flush
-- on a timer to show matches progressively as they're found — one batch per tick.
local FLUSH_MS = 80

-- unbuffered stdout splits lines at byte boundaries: data[1] continues the prior
-- partial, data[#data] is the new partial. Emits completed lines into sink.
local function split_lines(partial, data, sink)
  partial = partial .. data[1]
  for i = 2, #data do
    if partial ~= "" then sink[#sink + 1] = partial end
    partial = data[i]
  end
  return partial
end

local function current_qf_buf()
  local winid = vim.fn.getqflist({ winid = 0 }).winid
  if winid == 0 then return nil end
  return vim.api.nvim_win_get_buf(winid)
end

-- highlight every occurrence of query on qf lines [from..end); returns new count.
-- only the freshly-appended lines are scanned, so cost is per-batch not per-list.
local function highlight_new_lines(buf, query, from)
  local lq = query:lower()
  local lines = vim.api.nvim_buf_get_lines(buf, from, -1, false)
  for i, line in ipairs(lines) do
    local ll, pos = line:lower(), 1
    while true do
      local s, e = ll:find(lq, pos, true)
      if not s then break end
      vim.api.nvim_buf_add_highlight(buf, hl_ns, "QfSearchMatch", from + i - 1, s - 1, e)
      pos = e + 1
    end
  end
  return from + #lines
end

-- grep file contents with ripgrep, streaming matches into the quickfix list as rg
-- finds them; prompts if query is omitted. glob restricts to matching filenames
-- (e.g. "*.lua"). Entries are text-only with the jump target in user_data, opened
-- lazily on <CR> (see quickfix.lua), to avoid setqflist resolving every filename.
function M.search(query, dir, glob)
  dir = dir or vim.fn.getcwd()

  if not query or query == "" then
    vim.ui.input({ prompt = "Search: " }, function(input)
      if input and input ~= "" then M.search(input, dir, glob) end
    end)
    return
  end

  local cmd = { "rg", "--smart-case", "--line-number", "--no-heading", "--with-filename" }
  if glob then vim.list_extend(cmd, { "--glob", glob }) end
  vim.list_extend(cmd, { "--", query, dir })

  local pending = {} -- raw "path:lnum:match" lines awaiting parse + flush
  local partial = ""
  local opened  = false
  local count   = 0
  local hl_done = 0
  local timer
  local title   = 'Grep: "' .. query .. '"'

  vim.fn.setqflist({}, "r", { title = title, items = {} })

  local function flush()
    if #pending == 0 then return end
    local batch = pending
    pending = {}
    local items = {}
    for _, line in ipairs(batch) do
      local path, lnum, text = line:match("^(.-):(%d+):(.*)$")
      if path then
        items[#items + 1] = { text = text, user_data = { path = path, lnum = tonumber(lnum) } }
      end
    end
    if #items == 0 then return end
    vim.fn.setqflist({}, "a", { items = items })
    count = count + #items
    if not opened then
      vim.cmd("copen")
      opened = true
    end
    local buf = current_qf_buf()
    if buf then hl_done = highlight_new_lines(buf, query, hl_done) end
  end

  vim.fn.jobstart(cmd, {
    -- producer: cheap line reassembly only; the timer drives the UI flush
    on_stdout = function(_, data)
      partial = split_lines(partial, data, pending)
    end,
    on_exit = function(_, _)
      if timer and not timer:is_closing() then timer:stop(); timer:close() end
      if partial ~= "" then
        pending[#pending + 1] = partial
        partial = ""
      end
      flush()
      if count == 0 then
        vim.notify('No matches for "' .. query .. '"', vim.log.levels.INFO)
      end
      log.debug('[Grep] query="' .. query .. '" matches=' .. count)
    end,
  })

  -- timer fires on the libuv thread; schedule_wrap defers flush onto the main loop
  timer = vim.uv.new_timer()
  timer:start(FLUSH_MS, FLUSH_MS, vim.schedule_wrap(flush))
end

return M
