-- keymaps for custom functions
local search_string = require("configs.custom.functions.search_string")
local search_file = require("configs.custom.functions.search_file")

-- <leader>fg — prompt for a pattern and search into quickfix
vim.keymap.set("n", "<leader>fg", function() search_string.search() end, { desc = "Search into quickfix" })

-- <leader>fw — search the word under the cursor immediately
vim.keymap.set("n", "<leader>fw", function() search_string.search(vim.fn.expand("<cword>")) end, { desc = "Search word under cursor" })

-- <leader>* — search the word under the cursor (mnemonic: like *)
vim.keymap.set("n", "<leader>*", function() search_string.search(vim.fn.expand("<cword>")) end, { desc = "Search word under cursor" })

-- <leader>ff — prompt for a filename pattern and find with fd into quickfix
vim.keymap.set("n", "<leader>ff", function() search_file.file_search() end, { desc = "File search into quickfix" })

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

vim.api.nvim_create_user_command("Search", function(opts) search_string.search(strip_quotes(opts.args)) end, { nargs = "*", desc = "Search into quickfix" })
vim.api.nvim_create_user_command("Find", function(opts) search_file.file_search(strip_quotes(opts.args)) end, { nargs = "*", desc = "Find files into quickfix" })
