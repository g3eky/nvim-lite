local M = {}

if vim.fn.executable("rg") == 0 then
  vim.notify("rg not found — :Grep will not work", vim.log.levels.WARN)
end

-- reuse DiagnosticWarn colour for match highlights so it follows the colorscheme
local function set_hl()
  local warn = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false })
  vim.api.nvim_set_hl(0, "QfSearchMatch", { fg = warn.fg, bold = true })
end
set_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })

-- grep file contents with ripgrep; prompts if query is omitted
-- glob restricts search to matching filenames (e.g. "*.lua")
function M.search(query, dir, glob)
  dir = dir or vim.fn.getcwd()

  if not query or query == "" then
    vim.ui.input({ prompt = "Search: " }, function(input)
      if input and input ~= "" then
        M.search(input, dir, glob)
      end
    end)
    return
  end

  local cmd = { "rg", "--smart-case", "--line-number", "--no-heading", "--with-filename" }
  if glob then
    vim.list_extend(cmd, { "--glob", glob })
  end
  vim.list_extend(cmd, { "--", query, dir })
  local results = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(results, line)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and #results == 0 then
        vim.notify('No matches for "' .. query .. '"', vim.log.levels.INFO)
        return
      end

      local qf_items = vim.fn.getqflist({ lines = results, efm = "%f:%l:%m" }).items

      -- single match: open directly instead of going through quickfix
      if #qf_items == 1 then
        local item = qf_items[1]
        vim.cmd("edit " .. vim.fn.fnameescape(item.filename))
        vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
        return
      end

      vim.fn.setqflist({}, "r", {
        title = 'Grep: "' .. query .. '"',
        items = qf_items,
      })

      vim.cmd("copen")
      -- highlight all occurrences of the query in the quickfix buffer
      vim.schedule(function()
        local qf_winid = vim.fn.getqflist({ winid = 0 }).winid
        if qf_winid == 0 then return end
        local qf_bufnr = vim.api.nvim_win_get_buf(qf_winid)
        local ns = vim.api.nvim_create_namespace("search_string_hl")
        vim.api.nvim_buf_clear_namespace(qf_bufnr, ns, 0, -1)
        local lq = query:lower()
        for i, line in ipairs(vim.api.nvim_buf_get_lines(qf_bufnr, 0, -1, false)) do
          local pos = 1
          while true do
            local s, e = line:lower():find(lq, pos, true)
            if not s then break end
            vim.api.nvim_buf_add_highlight(qf_bufnr, ns, "QfSearchMatch", i - 1, s - 1, e)
            pos = e + 1
          end
        end
      end)
    end,
  })
end

return M
