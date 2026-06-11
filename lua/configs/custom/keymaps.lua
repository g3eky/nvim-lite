-- keymaps for custom functions
local search_string = require("configs.custom.functions.search_string")
local search_file = require("configs.custom.functions.search_file")
local quickfix = require("configs.custom.functions.quickfix")
-- <leader>ff / <leader>fs — open cmdline pre-filled so the query can be edited before running
vim.keymap.set("n", "<leader>ff", function() vim.api.nvim_feedkeys(":Find ", "n", false) end, { desc = "Find files into quickfix" })
vim.keymap.set("n", "<leader>fs", function() vim.api.nvim_feedkeys(":Grep ", "n", false) end, { desc = "Search into quickfix" })

-- <leader>* — prefill :Grep with the word under cursor / visual selection on the
-- cmdline (no <CR>) so it can be edited or extended before running
vim.keymap.set("n", "<leader>*", function()
  vim.api.nvim_feedkeys(":Grep " .. vim.fn.expand("<cword>"), "n", false)
end, { desc = "Search word under cursor" })
vim.keymap.set("v", "<leader>*", function()
  local saved = vim.fn.getreg('"')
  local savedtype = vim.fn.getregtype('"')
  vim.cmd("noautocmd normal! y")
  local text = vim.fn.getreg('"')
  vim.fn.setreg('"', saved, savedtype)
  vim.api.nvim_feedkeys(":Grep " .. text, "n", false)
end, { desc = "Search visual selection" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    -- open entry and close quickfix
    vim.keymap.set("n", "<leader><CR>", function() quickfix.open_entry(true) end, { buffer = true })
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

vim.api.nvim_create_user_command("Find", function(opts) search_file.file_search_exact(strip_quotes(opts.args)) end, { nargs = "*", desc = "Find files (exact) into quickfix" })
vim.api.nvim_create_user_command("FindFuzzy", function(opts) search_file.file_search(strip_quotes(opts.args)) end, { nargs = "*", desc = "Find files (fuzzy) into quickfix" })
