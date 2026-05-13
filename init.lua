-- setup optional setting flags for newvim setup
-- global settings that can disable specific features
-- of consequent plugins
require("settings")

-- setup any neovim options
require("configs.core")

-- load the plugin manager, lazy
require("configs.lazy")
