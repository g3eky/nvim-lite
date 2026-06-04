local M = {}

-- Run ripgrep for `query` rooted at `dir` (defaults to cwd) and populate quickfix.
function M.rg_search(query, dir)
  dir = dir or vim.fn.getcwd()

  if not query or query == "" then
    vim.ui.input({ prompt = "rg search: " }, function(input)
      if input and input ~= "" then
        M.rg_search(input, dir)
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
        vim.notify('rg: no matches for "' .. query .. '"', vim.log.levels.INFO)
        return
      end

      local qf_items = vim.fn.getqflist({ lines = results, efm = "%f:%l:%c:%m" }).items

      vim.fn.setqflist({}, "r", {
        title = 'rg: "' .. query .. '"',
        items = qf_items,
      })

      vim.cmd("copen")
      vim.cmd("cfirst")
    end,
  })
end

return M
