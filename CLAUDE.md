# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A minimal Neovim configuration built with [lazy.nvim](https://github.com/folke/lazy.nvim). It is a personal config, not a library — there are no build steps, tests, or package scripts.

## Running the config

Launch Neovim with this config in isolation:

```sh
NVIM_APPNAME=nvim-dev nvim
```

Plugin management is handled inside Neovim via `:Lazy`. To sync/install plugins after changes: `:Lazy sync`.

## Architecture

Initialization order in `init.lua`:

1. `lua/settings.lua` — global feature flags (`vim.g.*`) loaded first, because downstream files read them
2. `lua/configs/core/` — vanilla Neovim options, autocmds, keymaps (no plugin dependencies)
3. `lua/plugin-manager.lua` — bootstraps lazy.nvim and auto-imports everything under `lua/plugins/`

LSP (`lua/configs/lsp`) and DAP (`lua/configs/dap`) are stubbed and commented out.

## Global feature flags (`lua/settings.lua`)

These `vim.g` flags are read by multiple plugin files — change them here, not per-plugin:

| Flag | Type | Purpose |
|------|------|---------|
| `vim.g.nerd_font_enabled` | boolean | Gates all Nerd Font icons across every plugin |
| `vim.g.color_mode` | `"light"\|"dark"` | Intended for light/dark switching (partially implemented) |
| `vim.g.shell` | string | Shell path used by Neovim's terminal and options |

## Adding a plugin

Create a new file in `lua/plugins/<name>.lua` returning a lazy spec table. It is auto-discovered — no registration needed. Respect `vim.g.nerd_font_enabled` for any icon choices.

## Key design decisions

- `<Space>` is `mapleader`, `\` is `maplocalleader` (set in `lua/plugin-manager.lua` before lazy loads)
- Keymaps are split by category under `lua/configs/core/keymaps/`: `navigation`, `cmdmode`, `search`, `misc`
- Catppuccin is set to `macchiato` dark / `latte` light; the active flavour is forced to `catppuccin-macchiato` in `lua/plugins/catppuccin.lua` regardless of `color_mode` — this is a known TODO
- nvim-tree disables netrw entirely (`vim.g.loaded_netrw = 1`)
- `<F1>` toggles nvim-tree; `<Shift-F1>` reveals the current file
