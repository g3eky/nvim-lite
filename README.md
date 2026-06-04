Minimal neovim configuration



## Requirements

- **Neovim >= 0.10** (built with LuaJIT)
- **Git >= 2.19.0**
- **A [Nerd Font](https://www.nerdfonts.com/) >= 3.3** — required for icons; set `vim.g.nerd_font_enabled = false` in `lua/settings.lua` to opt out
- **True color terminal** — required for the colorscheme (most modern terminals; Terminal.app does not support this)
- **[fd](https://github.com/sharkdp/fd)** — required for the `:Find` command
- **[fzf](https://github.com/junegunn/fzf)** — required for the `:Find` command (fuzzy matching)
- **[ripgrep](https://github.com/BurntSushi/ripgrep)** — required for the `:Search` command

## Custom features

### `:Find [pattern]`

Fuzzy file search. Results open in the quickfix list with matched characters highlighted. Single match opens directly.

Keymap: `<leader>ff` — [f]ind [f]ile

### `:Search [query] [glob]`

Search file contents. Results open in the quickfix list with matches highlighted. Single match opens directly.

When two arguments are given, the last is treated as a file glob. Use quotes for multi-word queries.

```
:Search TODO
:Search foo *.lua
:Search "foo bar" *.c
```

Keymaps: `<leader>fs` ([f]ind [s]tring) to prompt, `<leader>*` to search word under cursor.

### Quickfix

`<CR>` opens the entry and moves focus to it. `<leader><CR>` opens the entry and closes the quickfix list.
