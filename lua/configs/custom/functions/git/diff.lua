local M = {}

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

  -- working file into diff mode, git version beside it on the left
  vim.cmd("diffthis")
  vim.cmd("leftabove vsplit")
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

  -- q closes the git pane and turns diff mode back off in the file window
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd("diffoff")
  end, { buffer = buf, nowait = true, desc = "Close git diff" })
end

return M
