local M = {}

local log_path = vim.fn.stdpath("log") .. "/user.log"

local levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

local function current_level()
  return levels[vim.g.log_level] or levels.INFO
end

local function write(level, msg)
  if levels[level] < current_level() then return end
  local lines = vim.split("[" .. level .. "] " .. msg, "\n", { plain = true })
  local ok, err = pcall(vim.fn.writefile, lines, log_path, "a")
  if not ok then vim.notify("log write error: " .. tostring(err), vim.log.levels.WARN) end
end

function M.debug(msg) write("DEBUG", msg) end
function M.info(msg)  write("INFO",  msg) end
function M.warn(msg)  write("WARN",  msg) end
function M.error(msg) write("ERROR", msg) end

return M
