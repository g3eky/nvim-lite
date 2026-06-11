local M = {}

if vim.fn.executable("fd") == 0 then
  vim.notify("fd not found — :Find will not work", vim.log.levels.WARN)
end

if vim.fn.executable("fzf") == 0 then
  vim.notify("fzf not found — :FindFuzzy will not work", vim.log.levels.WARN)
end

local log = require("configs.custom.functions.log")
local function now() return vim.uv.hrtime() end
local function ms(t) return string.format("%.1fms", t / 1e6) end

local function fmt_times(label, query, times)
  local lines = { "[" .. label .. '] query="' .. query .. '"' }
  for _, entry in ipairs(times) do
    table.insert(lines, "  " .. entry[1] .. ": " .. ms(entry[2]))
  end
  return table.concat(lines, "\n")
end

local function apply_exact_hl(qf_bufnr, pattern)
  local ns = vim.api.nvim_create_namespace("search_file_hl")
  vim.api.nvim_buf_clear_namespace(qf_bufnr, ns, 0, -1)
  local lp = pattern:lower()
  for i, line in ipairs(vim.api.nvim_buf_get_lines(qf_bufnr, 0, -1, false)) do
    local col = line:lower():find(lp, 1, true)
    if col then
      vim.api.nvim_buf_add_highlight(qf_bufnr, ns, "QfSearchMatch", i - 1, col - 1, col - 1 + #pattern)
    end
  end
end

local function apply_fuzzy_hl(qf_bufnr, pattern)
  local ns = vim.api.nvim_create_namespace("search_file_hl")
  vim.api.nvim_buf_clear_namespace(qf_bufnr, ns, 0, -1)
  local lp = pattern:lower()
  for i, line in ipairs(vim.api.nvim_buf_get_lines(qf_bufnr, 0, -1, false)) do
    local ll = line:lower()
    local col = ll:find(lp, 1, true)
    if col then
      vim.api.nvim_buf_add_highlight(qf_bufnr, ns, "QfSearchMatch", i - 1, col - 1, col - 1 + #pattern)
    else
      -- fzf matched but no contiguous substring; highlight individual chars greedily
      local si = 1
      for pi = 1, #lp do
        local fc = ll:find(lp:sub(pi, pi), si, true)
        if not fc then break end
        vim.api.nvim_buf_add_highlight(qf_bufnr, ns, "QfSearchMatch", i - 1, fc - 1, fc)
        si = fc + 1
      end
    end
  end
end

local function get_qf_bufnr()
  local winid = vim.fn.getqflist({ winid = 0 }).winid
  if winid == 0 then return nil end
  return vim.api.nvim_win_get_buf(winid)
end

-- exact file search using fd's built-in substring/regex matching; no fzf
function M.file_search_exact(pattern, dir)
  dir = dir or vim.fn.getcwd()

  if not pattern or pattern == "" then
    vim.ui.input({ prompt = "Find: " }, function(input)
      if input and input ~= "" then
        M.file_search_exact(input, dir)
      end
    end)
    return
  end

  local t_start = now()
  local results = {}

  vim.fn.jobstart({ "fd", "--type", "f", pattern, dir }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then table.insert(results, line) end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and #results == 0 then
        vim.notify('No files matching "' .. pattern .. '"', vim.log.levels.INFO)
        return
      end

      if #results == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(results[1]))
        return
      end

      -- text-only entries (no filename) avoid setqflist's O(n^2) per-file buffer
      -- resolution; the path lives in .text and is opened lazily on <CR> (quickfix.lua)
      local qf_items = {}
      for _, path in ipairs(results) do
        table.insert(qf_items, { text = path })
      end

      vim.fn.setqflist({}, "r", { title = 'Find: "' .. pattern .. '"', items = qf_items })
      vim.cmd("copen")

      -- schedule so copen has drawn the buffer before we look up its bufnr
      vim.schedule(function()
        local t0 = now()
        local bufnr = get_qf_bufnr()
        if bufnr then apply_exact_hl(bufnr, pattern) end
        log.debug(fmt_times("Find", pattern, {
          { "highlight", now() - t0 },
          { "total",     now() - t_start },
        }))
      end)
    end,
  })
end

-- fuzzy file search using fd + fzf; prompts if pattern is omitted
function M.file_search(pattern, dir)
  dir = dir or vim.fn.getcwd()

  if not pattern or pattern == "" then
    vim.ui.input({ prompt = "File search: " }, function(input)
      if input and input ~= "" then
        M.file_search(input, dir)
      end
    end)
    return
  end

  local t_start = now()
  local shell_cmd = "fd --type f . " .. vim.fn.shellescape(dir) .. " | fzf --filter " .. vim.fn.shellescape(pattern)
  local results = {}

  vim.fn.jobstart({ "sh", "-c", shell_cmd }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then table.insert(results, line) end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and #results == 0 then
        vim.notify('No files matching "' .. pattern .. '"', vim.log.levels.INFO)
        return
      end

      if #results == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(results[1]))
        return
      end

      -- direct (substring) matches first, fuzzy below
      local t_sort = now()
      local lp = pattern:lower()
      local direct, fuzzy = {}, {}
      for _, path in ipairs(results) do
        if path:lower():find(lp, 1, true) then
          table.insert(direct, path)
        else
          table.insert(fuzzy, path)
        end
      end
      -- text-only entries (see file_search_exact): dodge per-file buffer resolution
      local qf_items = {}
      for _, p in ipairs(direct) do table.insert(qf_items, { text = p }) end
      for _, p in ipairs(fuzzy) do table.insert(qf_items, { text = p }) end
      vim.fn.setqflist({}, "r", { title = 'FindFuzzy: "' .. pattern .. '"', items = qf_items })
      t_sort = now() - t_sort

      vim.cmd("copen")

      -- schedule so copen has drawn the buffer before we look up its bufnr
      vim.schedule(function()
        local t0 = now()
        local bufnr = get_qf_bufnr()
        if bufnr then apply_fuzzy_hl(bufnr, pattern) end
        log.debug(fmt_times("FindFuzzy", pattern, {
          { "sort",      t_sort },
          { "highlight", now() - t0 },
          { "total",     now() - t_start },
        }))
      end)
    end,
  })
end

return M
