-- setup optional setting flags for neovim setup
-- load this first as the following configs can depend on these global settings
require("settings")

-- setup any vanilla neovim options
require("configs.core")

-- custom functions and their keymaps
require("configs.custom")

-- load the plugin manager, lazy
require("plugin-manager")

