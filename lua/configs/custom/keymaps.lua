-- keymaps for custom functions
local rg = require("configs.custom.functions.rg_search")

-- <leader>fg — prompt for a pattern and search with ripgrep into quickfix
vim.keymap.set("n", "<leader>fg", function() rg.rg_search() end, { desc = "rg search into quickfix" })

-- <leader>fw — search the word under the cursor immediately
vim.keymap.set("n", "<leader>fw", function() rg.rg_search(vim.fn.expand("<cword>")) end, { desc = "rg search word under cursor" })

-- <leader>* — search the word under the cursor (mnemonic: like * but with rg)
vim.keymap.set("n", "<leader>*", function() rg.rg_search(vim.fn.expand("<cword>")) end, { desc = "rg search word under cursor" })

vim.api.nvim_create_user_command("Rg", function(opts) rg.rg_search(opts.args) end, { nargs = 1, desc = "rg search into quickfix" })
