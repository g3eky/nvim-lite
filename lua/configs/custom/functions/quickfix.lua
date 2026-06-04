local M = {}

function M.setup()
  _G._qf_text_func = function(info)
    local items = vim.fn.getqflist({ id = info.id, items = 1 }).items
    local result = {}
    for i = info.start_idx, info.end_idx do
      local item = items[i]
      local fname = vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ":.")
      if item.lnum > 0 then
        local entry = fname .. "|" .. item.lnum
        if item.col > 0 then entry = entry .. " col " .. item.col end
        table.insert(result, entry .. "| " .. item.text)
      else
        table.insert(result, fname)
      end
    end
    return result
  end

  vim.o.quickfixtextfunc = "v:lua._qf_text_func"

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "qf",
    callback = function()
      vim.keymap.set("n", "<CR>", function()
        local qf_win = vim.fn.win_getid()
        vim.cmd(vim.fn.line(".") .. "cc")
        vim.fn.win_gotoid(qf_win)
      end, { buffer = true })
    end,
  })
end

return M
