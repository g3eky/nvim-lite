

-- TODO: ensure the false state is used everywhere
-- enable this to turn on all nerd font features
---@type boolean
vim.g.nerd_font_enabled = true

---@type string
vim.g.shell = "/opt/homebrew/bin/fish"

-- TODO: implement light mode everywhere
---@type "light"|"dark"
vim.g.color_mode = "light"

-- minimum level written to the log file (see configs/custom/functions/log.lua)
---@type "DEBUG"|"INFO"|"WARN"|"ERROR"
-- vim.g.log_level = 1
vim.g.log_level = "INFO"
