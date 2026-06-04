local M = {}

if vim.fn.executable("fd") == 0 then
  vim.notify("fd not found — :Find will not work", vim.log.levels.WARN)
end

if vim.fn.executable("fzf") == 0 then
  vim.notify("fzf not found — :Find will not work", vim.log.levels.WARN)
end

function M.file_search(pattern, dir)
  dir = dir or vim.fn.getcwd()

  if not pattern or pattern == "" then
    vim.ui.input({ prompt = "File search: " }, function(input)
      if input and input ~= "" then
        M.file_search(input, dir)
      end
    end)
    return
  end

  local shell_cmd = "fd --type f . " .. vim.fn.shellescape(dir) .. " | fzf --filter " .. vim.fn.shellescape(pattern)
  local cmd = { "sh", "-c", shell_cmd }
  local results = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(results, line)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and #results == 0 then
        vim.notify('No files matching "' .. pattern .. '"', vim.log.levels.INFO)
        return
      end

      local qf_items = {}
      for _, path in ipairs(results) do
        table.insert(qf_items, { filename = path })
      end

      if #qf_items == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(results[1]))
        return
      end

      vim.fn.setqflist({}, "r", {
        title = 'Find: "' .. pattern .. '"',
        items = qf_items,
      })

      vim.cmd("copen")
      vim.schedule(function()
        local qf_winid = vim.fn.getqflist({ winid = 0 }).winid
        if qf_winid == 0 then return end
        local qf_bufnr = vim.api.nvim_win_get_buf(qf_winid)
        local ns = vim.api.nvim_create_namespace("search_file_hl")
        vim.api.nvim_buf_clear_namespace(qf_bufnr, ns, 0, -1)
        local lp = pattern:lower()
        for i, line in ipairs(vim.api.nvim_buf_get_lines(qf_bufnr, 0, -1, false)) do
          local ll = line:lower()
          local si = 1
          for pi = 1, #lp do
            local col = ll:find(lp:sub(pi, pi), si, true)
            if not col then break end
            vim.api.nvim_buf_add_highlight(qf_bufnr, ns, "QfSearchMatch", i - 1, col - 1, col)
            si = col + 1
          end
        end
      end)
    end,
  })
end

return M
