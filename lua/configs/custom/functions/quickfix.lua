local M = {}

-- Open the quickfix entry under the cursor.
-- To dodge setqflist's O(n^2) per-file buffer resolution, our search commands emit
-- text-only entries (bufnr == 0) and keep the real jump target in .user_data:
--   * file finders (Find/FindFuzzy): no user_data, the path is in .text
--   * grep: user_data = { path = ..., lnum = ..., col = ... }
-- These have no buffer to jump to, so we :edit the path here — lazily, one at a
-- time. Anything with a real bufnr falls back to the normal :cc jump.
---@param close boolean close the quickfix window after opening
function M.open_entry(close)
  local line = vim.fn.line(".")
  local item = vim.fn.getqflist()[line]

  if item and item.bufnr == 0 then
    local ud = type(item.user_data) == "table" and item.user_data or {}
    local path = ud.path or item.text
    local qf_win = vim.fn.win_getid()
    if close then
      vim.cmd("cclose") -- focus returns to the window we came from
    else
      vim.cmd.wincmd("p") -- back to the previous window
      if vim.fn.win_getid() == qf_win then vim.cmd.wincmd("k") end
    end
    vim.cmd.edit(vim.fn.fnameescape(path))
    if ud.lnum and ud.lnum > 0 then
      vim.api.nvim_win_set_cursor(0, { ud.lnum, math.max((ud.col or 1) - 1, 0) })
    end
    if not close then vim.fn.win_gotoid(qf_win) end
  else
    local qf_win = vim.fn.win_getid()
    vim.cmd(line .. "cc")
    if close then vim.cmd("cclose") else vim.fn.win_gotoid(qf_win) end
  end
end

function M.setup()
  _G._qf_text_func = function(info)
    local items = vim.fn.getqflist({ id = info.id, items = 1 }).items
    local result = {}
    for i = info.start_idx, info.end_idx do
      local item = items[i]
      local ud = type(item.user_data) == "table" and item.user_data or nil
      if ud and ud.path then
        -- grep text-only entry: path | line [col] | match
        local entry = vim.fn.fnamemodify(ud.path, ":.") .. "|" .. (ud.lnum or 0)
        if ud.col and ud.col > 0 then entry = entry .. " col " .. ud.col end
        table.insert(result, entry .. "| " .. item.text)
      elseif item.bufnr == 0 then
        -- file-finder text-only entry: the path lives in .text
        table.insert(result, vim.fn.fnamemodify(item.text, ":."))
      else
        local fname = vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ":.")
        if item.lnum > 0 then
          local entry = fname .. "|" .. item.lnum
          if item.col > 0 then entry = entry .. " col " .. item.col end
          table.insert(result, entry .. "| " .. item.text)
        else
          table.insert(result, fname)
        end
      end
    end
    return result
  end

  vim.o.quickfixtextfunc = "v:lua._qf_text_func"

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "qf",
    callback = function()
      vim.keymap.set("n", "<CR>", function() M.open_entry(false) end, { buffer = true })
      vim.keymap.set("n", "<S-CR>", function() M.open_entry(true) end, { buffer = true })
    end,
  })
end

return M
