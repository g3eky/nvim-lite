local M = {}

function M.search(query, dir)
  dir = dir or vim.fn.getcwd()

  if not query or query == "" then
    vim.ui.input({ prompt = "Search: " }, function(input)
      if input and input ~= "" then
        M.search(input, dir)
      end
    end)
    return
  end

  local cmd = { "rg", "--vimgrep", "--smart-case", "--", query, dir }
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
        vim.notify('No matches for "' .. query .. '"', vim.log.levels.INFO)
        return
      end

      local qf_items = vim.fn.getqflist({ lines = results, efm = "%f:%l:%c:%m" }).items

      vim.fn.setqflist({}, "r", {
        title = 'Search: "' .. query .. '"',
        items = qf_items,
      })

      vim.cmd("copen")
      vim.cmd("cfirst")
    end,
  })
end

return M
