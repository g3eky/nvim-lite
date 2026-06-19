local M = {}

local quickfix = require("configs.custom.functions.quickfix")

if vim.fn.executable("git") == 0 then
  vim.notify("git not found — :GitDiff will not work", vim.log.levels.WARN)
end

-- Diff the current file against git using Neovim's native diff mode. The working buffer
-- stays on the right (live, so unsaved edits show too); the git version opens in a
-- diff-mode vsplit on the left. With no arg this compares against the index (plain
-- `git diff`); an arg is the revision to compare against, e.g. :GitDiff HEAD~1, main.
function M.show(args)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("GitDiff: buffer is not a file", vim.log.levels.WARN)
    return
  end

  local dir = vim.fn.fnamemodify(file, ":h")
  local ft = vim.bo.filetype

  -- repo-relative path, so `git show <rev>:<path>` resolves from anywhere
  local rel = vim.fn.systemlist({ "git", "-C", dir, "ls-files", "--full-name", "--", file })[1]
  if vim.v.shell_error ~= 0 or not rel or rel == "" then
    vim.notify("GitDiff: file is not tracked by git", vim.log.levels.WARN)
    return
  end

  local rev = vim.trim(args or "")
  local object = (rev == "" and ":" or rev .. ":") .. rel
  local label = rev == "" and "index" or rev

  local content = vim.fn.systemlist({ "git", "-C", dir, "show", object })
  if vim.v.shell_error ~= 0 then
    vim.notify("GitDiff: " .. table.concat(content, " "), vim.log.levels.ERROR)
    return
  end

  -- working file (modifiable) stays on the left in diff mode, read-only git version
  -- opens beside it on the right
  vim.cmd("diffthis")
  local file_win = vim.api.nvim_get_current_win()
  vim.cmd("rightbelow vsplit")
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = ft
  pcall(vim.api.nvim_buf_set_name, buf, rel .. " @ " .. label)

  vim.cmd("diffthis")

  -- leave the cursor in the editable working-file window
  if vim.api.nvim_win_is_valid(file_win) then
    vim.api.nvim_set_current_win(file_win)
  end

  -- q closes the git pane and turns diff mode back off in the file window
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd("diffoff")
  end, { buffer = buf, nowait = true, desc = "Close git diff" })
end

-- List every changed file into the quickfix list for browsing. With no arg this
-- defaults to comparing against HEAD (so the list captures both staged and
-- unstaged changes); an arg is the revision to compare against, e.g.
-- :GitDiffFull main. Selecting an entry (<CR>) opens that file and shows its
-- diff against the same base via M.show.
function M.show_all(args)
  local cwd = vim.fn.getcwd()
  local root = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })[1]
  if vim.v.shell_error ~= 0 or not root or root == "" then
    vim.notify("GitDiffFull: not in a git repository", vim.log.levels.WARN)
    return
  end

  local rev = vim.trim(args or "")
  local base = rev == "" and "HEAD" or rev

  local files = vim.fn.systemlist({ "git", "-C", root, "diff", "--name-only", base })
  if vim.v.shell_error ~= 0 then
    vim.notify("GitDiffFull: " .. table.concat(files, " "), vim.log.levels.ERROR)
    return
  end
  if #files == 0 then
    vim.notify("GitDiffFull: no changes against " .. base, vim.log.levels.INFO)
    return
  end

  -- text-only entries (see search_file.lua / quickfix.lua): the absolute path
  -- lives in .text and is opened lazily on <CR>, dodging per-file buffer resolution
  local qf_items = {}
  for _, path in ipairs(files) do
    if path ~= "" then table.insert(qf_items, { text = root .. "/" .. path }) end
  end

  vim.fn.setqflist({}, "r", { title = "GitDiffFull: " .. base, items = qf_items })
  vim.cmd("copen")

  -- override <CR> in this qf window: open the selected file and diff it against
  -- the same base. <S-CR> keeps the plain "just open" behaviour from quickfix.lua.
  vim.schedule(function()
    local winid = vim.fn.getqflist({ winid = 0 }).winid
    if winid == 0 then return end
    local bufnr = vim.api.nvim_win_get_buf(winid)
    vim.keymap.set("n", "<CR>", function()
      quickfix.open_entry(true)
      M.show(rev)
    end, { buffer = bufnr, nowait = true, desc = "Open file and show git diff" })
  end)
end

return M
