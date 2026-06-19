-- keymaps for custom functions
local search_string = require("configs.custom.functions.search_string")
local search_file = require("configs.custom.functions.search_file")
local quickfix = require("configs.custom.functions.quickfix")
local git_blame = require("configs.custom.functions.git.blame")
local git_diff = require("configs.custom.functions.git.diff")
-- <leader>ff / <leader>fs — open cmdline pre-filled so the query can be edited before running
vim.keymap.set("n", "<leader>ff", function() vim.api.nvim_feedkeys(":Find ", "n", false) end, { desc = "Find files into quickfix" })
vim.keymap.set("n", "<leader>fs", function() vim.api.nvim_feedkeys(":Grep ", "n", false) end, { desc = "Search into quickfix" })

-- <leader>* — fill the cmdline and run it (the <CR> auto-presses enter): in normal
-- mode the word under cursor with word boundaries (like vim's *), in visual mode
-- the selection quoted (one literal phrase)
local function feed_cmd(cmd)
  local keys = vim.api.nvim_replace_termcodes(cmd .. "<CR>", true, false, true)
  vim.api.nvim_feedkeys(keys, "nt", false)
end
vim.keymap.set("n", "<leader>*", function()
  feed_cmd(":Grep \\b" .. vim.fn.expand("<cword>") .. "\\b")
end, { desc = "Search word under cursor" })
vim.keymap.set("v", "<leader>*", function()
  local saved = vim.fn.getreg('"')
  local savedtype = vim.fn.getregtype('"')
  vim.cmd("noautocmd normal! y")
  local text = vim.fn.getreg('"')
  vim.fn.setreg('"', saved, savedtype)
  feed_cmd(':Grep "' .. text .. '"')
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
  local query, glob
  -- a quoted query is taken as-is (may contain spaces); an optional glob may follow it.
  -- otherwise the last of multiple bare args is the glob, the rest joined is the query.
  local quoted = opts.args:match('^%s*"(.-)"') or opts.args:match("^%s*'(.-)'")
  if quoted then
    query = quoted
    local rest = opts.args:match('^%s*".-"%s*(.*)$') or opts.args:match("^%s*'.-'%s*(.*)$")
    if rest and rest ~= "" then glob = rest end
  else
    local fargs = opts.fargs
    if #fargs > 1 then glob = table.remove(fargs) end
    query = #fargs > 0 and table.concat(fargs, " ") or nil
  end
  search_string.search(query, nil, glob)
end, { nargs = "*", desc = "Search into quickfix" })

vim.api.nvim_create_user_command("Find", function(opts) search_file.file_search_exact(strip_quotes(opts.args)) end, { nargs = "*", desc = "Find files (exact) into quickfix" })
vim.api.nvim_create_user_command("FindFuzzy", function(opts) search_file.file_search(strip_quotes(opts.args)) end, { nargs = "*", desc = "Find files (fuzzy) into quickfix" })

vim.api.nvim_create_user_command("GitBlame", git_blame.toggle, { desc = "Toggle git blame gutter" })
-- <leader>tb — giT Blame
vim.keymap.set("n", "<leader>tb", git_blame.toggle, { desc = "Toggle git blame gutter" })

vim.api.nvim_create_user_command("GitDiff", function(opts) git_diff.show(opts.args) end, { nargs = "*", complete = "file", desc = "Show git diff in a vsplit" })
-- <leader>td — giT Diff (working tree)
vim.keymap.set("n", "<leader>td", function() git_diff.show("") end, { desc = "Show git diff in a vsplit" })

vim.api.nvim_create_user_command("GitDiffFull", function(opts) git_diff.show_all(opts.args) end, { nargs = "*", desc = "List all changed files into the quickfix list" })
-- <leader>tD — giT Diff (all changed files into quickfix)
vim.keymap.set("n", "<leader>tD", function() git_diff.show_all("") end, { desc = "List all changed files into the quickfix list" })
