local M = {}

if vim.fn.executable("git") == 0 then
  vim.notify("git not found — :Blame will not work", vim.log.levels.WARN)
end

-- One blame gutter at a time. We keep the blame text in a scratch window pinned to
-- the left of the source window and scrollbind/cursorbind the two so the blame for
-- line N always sits beside line N — without ever touching the source buffer.
local state = { blame_win = nil, src_win = nil, group = nil }

local ns = vim.api.nvim_create_namespace("gitblame")

-- Existing semantic groups, so colours track the active colorscheme (catppuccin):
-- "Function" is blue, "Constant" is peach/orange. We alternate between the two every
-- time the commit changes from the line above, so adjacent commit blocks always differ.
local PALETTE = { "Function", "Constant" }

local function close()
  if state.blame_win and vim.api.nvim_win_is_valid(state.blame_win) then
    -- normally just close the gutter; but if it is the last window (the source file
    -- was quit out from under it), closing isn't allowed — quit it instead, which
    -- exits nvim: the natural end of quitting the file the blame was attached to
    local ok = pcall(vim.api.nvim_win_close, state.blame_win, true)
    if not ok and vim.api.nvim_win_is_valid(state.blame_win) then
      vim.api.nvim_set_current_win(state.blame_win)
      pcall(vim.cmd, "quit")
    end
  end
  if state.src_win and vim.api.nvim_win_is_valid(state.src_win) then
    vim.api.nvim_win_call(state.src_win, function()
      vim.wo.scrollbind = false
      vim.wo.cursorbind = false
    end)
  end
  if state.group then
    pcall(vim.api.nvim_del_augroup_by_id, state.group)
  end
  state.blame_win, state.src_win, state.group = nil, nil, nil
end

-- --line-porcelain repeats the full commit header before every line, so each block
-- is self-contained: a 40-hex header line, then author/time fields, then the source
-- line (tab-prefixed). Blocks arrive in final-line order, so we just append.
local function parse(out)
  local entries, hash, author, time = {}, nil, nil, nil
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
        entries[#entries + 1] = { hash = "0000000", date = "", author = "Not Committed Yet", uncommitted = true }
      else
        local date = time and os.date("%Y-%m-%d", time) or ""
        entries[#entries + 1] = { hash = hash:sub(1, 7), date = date, author = author or "" }
      end
    end
  end
  return entries
end

-- Turn parsed entries into gutter text plus the highlight spans for each line.
-- Layout per line: "<hash:8> <date:10> <author>". We compute span offsets from the
-- field widths so the highlights stay aligned even if a colorscheme changes the font.
local function render(entries)
  local lines, spans = {}, {}
  local prev_hash, idx = nil, 0
  for i, e in ipairs(entries) do
    local hash_field = string.format("%-8s", e.hash)
    local date_field = string.format("%-10s", e.date)
    local text = hash_field .. " " .. date_field .. " " .. e.author
    lines[i] = text

    local row = i - 1
    if e.uncommitted then
      spans[#spans + 1] = { row, 0, #text, "DiagnosticWarn" }
    else
      -- flip colour only when the commit differs from the line above
      if e.hash ~= prev_hash then
        idx = idx + 1
      end
      prev_hash = e.hash
      local hl = PALETTE[(idx % #PALETTE) + 1]
      local date_start = #hash_field + 1
      local author_start = date_start + #date_field + 1
      spans[#spans + 1] = { row, 0, #e.hash, hl }                         -- hash
      spans[#spans + 1] = { row, date_start, date_start + #e.date, "Comment" } -- date dimmed
      spans[#spans + 1] = { row, author_start, #text, hl }                -- author matches its commit
    end
  end
  return lines, spans
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

  local lines, spans = render(parse(out))
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
  for _, s in ipairs(spans) do
    vim.api.nvim_buf_set_extmark(buf, ns, s[1], s[2], { end_col = s[3], hl_group = s[4] })
  end

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

  -- q closes the gutter. Closing either window any other way (:q, :close, <C-w>q) also
  -- tears the pair down, so quitting the source file quits blame too and the gutter
  -- never lingers. Deferred: closing a window synchronously inside WinClosed aborts an
  -- in-flight :q (E855), so run the teardown on the next tick instead.
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, desc = "Close blame gutter" })
  state.group = vim.api.nvim_create_augroup("gitblame_close", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = state.group,
    callback = function(ev)
      local closed = tonumber(ev.match)
      if closed == blame_win or closed == src_win then vim.schedule(close) end
    end,
  })

  -- keep the source window focused so the user can carry on editing
  vim.api.nvim_set_current_win(src_win)
  vim.cmd("syncbind")
end

return M
