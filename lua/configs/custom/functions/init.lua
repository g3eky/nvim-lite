-- load each custom function module here
require("configs.custom.functions.log")
require("configs.custom.functions.search_string")
require("configs.custom.functions.search_file")
require("configs.custom.functions.git.blame")
require("configs.custom.functions.git.diff")
require("configs.custom.functions.quickfix").setup()
