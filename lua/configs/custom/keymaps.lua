-- keymaps for custom functions
local search_string = require("configs.custom.functions.search_string")
local search_file = require("configs.custom.functions.search_file")
-- <leader>ff — prompt for a filename pattern and find with fd into quickfix
vim.keymap.set("n", "<leader>ff", function() search_file.file_search() end, { desc = "File search into quickfix" })

-- <leader>fs — prompt for a string and search into quickfix
vim.keymap.set("n", "<leader>fs", function() search_string.search() end, { desc = "Search into quickfix" })

-- <leader>* — search word under cursor (normal) or visual selection (visual)
vim.keymap.set("n", "<leader>*", function() search_string.search(vim.fn.expand("<cword>")) end, { desc = "Search word under cursor" })
vim.keymap.set("v", "<leader>*", function()
  local saved = vim.fn.getreg('"')
  local savedtype = vim.fn.getregtype('"')
  vim.cmd("noautocmd normal! y")
  local text = vim.fn.getreg('"')
  vim.fn.setreg('"', saved, savedtype)
  search_string.search(text)
end, { desc = "Search visual selection" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    -- open entry and close quickfix
    vim.keymap.set("n", "<leader><CR>", function()
      vim.cmd("cc " .. vim.fn.line("."))
      vim.cmd("cclose")
    end, { buffer = true })
  end,
})

-- <leader>q — toggle quickfix window
vim.keymap.set("n", "<leader>q", function()
  local wins = vim.fn.getqflist({ winid = 0 }).winid
  if wins ~= 0 then
    vim.cmd("cclose")
  else
    vim.cmd("copen")
  end
end, { desc = "Toggle quickfix" })

local function strip_quotes(s)
  return s:match('^"(.*)"$') or s:match("^'(.*)'$") or s
end

vim.api.nvim_create_user_command("Grep", function(opts)
  local fargs = opts.fargs
  local glob
  -- last arg is always the glob when multiple args are given; quote the query for spaces
  if #fargs > 1 then
    glob = table.remove(fargs)
  end
  local query = #fargs > 0 and table.concat(fargs, " ") or nil
  search_string.search(query, nil, glob)
end, { nargs = "*", desc = "Search into quickfix" })
vim.api.nvim_create_user_command("Find", function(opts) search_file.file_search(strip_quotes(opts.args)) end, { nargs = "*", desc = "Find files into quickfix" })
