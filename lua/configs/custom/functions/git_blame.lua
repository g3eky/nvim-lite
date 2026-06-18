local M = {}

if vim.fn.executable("git") == 0 then
  vim.notify("git not found — :Blame will not work", vim.log.levels.WARN)
end

-- One blame gutter at a time. We keep the blame text in a scratch window pinned to
-- the left of the source window and scrollbind/cursorbind the two so the blame for
-- line N always sits beside line N — without ever touching the source buffer.
local state = { blame_win = nil, src_win = nil }

local function close()
  if state.blame_win and vim.api.nvim_win_is_valid(state.blame_win) then
    vim.api.nvim_win_close(state.blame_win, true)
  end
  if state.src_win and vim.api.nvim_win_is_valid(state.src_win) then
    vim.api.nvim_win_call(state.src_win, function()
      vim.wo.scrollbind = false
      vim.wo.cursorbind = false
    end)
  end
  state.blame_win, state.src_win = nil, nil
end

-- --line-porcelain repeats the full commit header before every line, so each block
-- is self-contained: a 40-hex header line, then author/time fields, then the source
-- line (tab-prefixed). Blocks arrive in final-line order, so we just append.
local function parse(out)
  local lines, hash, author, time = {}, nil, nil, nil
  for _, l in ipairs(out) do
    local h = l:match("^(%x+) %d+ %d+")
    if h then
      hash, author, time = h, nil, nil
    elseif l:sub(1, 7) == "author " then
      author = l:sub(8)
    elseif l:sub(1, 12) == "author-time " then
      time = tonumber(l:sub(13))
    elseif l:sub(1, 1) == "\t" then
      -- content line closes the block; emit the gutter entry for this source line
      if hash:match("^0+$") then
        lines[#lines + 1] = string.format("%-8s %-10s %s", "0000000", "", "Not Committed Yet")
      else
        local date = time and os.date("%Y-%m-%d", time) or ""
        lines[#lines + 1] = string.format("%-8s %-10s %s", hash:sub(1, 7), date, author or "")
      end
    end
  end
  return lines
end

function M.toggle()
  if state.blame_win and vim.api.nvim_win_is_valid(state.blame_win) then
    close()
    return
  end

  local src_win = vim.api.nvim_get_current_win()
  local src_buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(src_buf)
  if file == "" then
    vim.notify("Blame: buffer is not a file", vim.log.levels.WARN)
    return
  end
  if vim.bo[src_buf].modified then
    vim.notify("Blame: save the buffer first", vim.log.levels.WARN)
    return
  end

  local dir = vim.fn.fnamemodify(file, ":h")
  local out = vim.fn.systemlist({ "git", "-C", dir, "blame", "--line-porcelain", "--", file })
  if vim.v.shell_error ~= 0 then
    vim.notify("Blame: " .. table.concat(out, " "), vim.log.levels.ERROR)
    return
  end

  local lines = parse(out)
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, #l)
  end
  width = math.min(math.max(width, 20), 60)

  -- open the gutter to the left of the source window
  vim.cmd("leftabove vsplit")
  local blame_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(blame_win, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "gitblame"
  vim.api.nvim_win_set_width(blame_win, width)

  local wo = vim.wo[blame_win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.wrap = false
  wo.cursorline = true
  wo.winfixwidth = true

  -- bind the two windows so blame for line N stays beside source line N
  for _, w in ipairs({ blame_win, src_win }) do
    vim.api.nvim_win_call(w, function()
      vim.wo.scrollbind = true
      vim.wo.cursorbind = true
    end)
  end

  state.blame_win, state.src_win = blame_win, src_win

  -- q closes the gutter; clean up scrollbind if it's closed any other way too
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, desc = "Close blame gutter" })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(blame_win),
    once = true,
    callback = close,
  })

  -- keep the source window focused so the user can carry on editing
  vim.api.nvim_set_current_win(src_win)
  vim.cmd("syncbind")
end

return M
