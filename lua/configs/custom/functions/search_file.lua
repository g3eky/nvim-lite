local M = {}

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

  local cmd = { "fd", "--type", "f", "--", pattern, dir }
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
        table.insert(qf_items, { filename = path, lnum = 1, col = 1, text = path })
      end

      vim.fn.setqflist({}, "r", {
        title = 'FileSearch: "' .. pattern .. '"',
        items = qf_items,
      })

      vim.cmd("copen")
      vim.cmd("cfirst")
    end,
  })
end

return M
