# nvim

nvim is a full config shipped in the repo, not just a colourscheme bolted
onto your own — `dotfiles/nvim/` carries `init.lua`, `lua/config.lua`,
`lua/keymaps.lua`, `lua/commands.lua`, `lua/utils.lua`, `lazy-lock.json` (the
plugin-manager lockfile), and the matugen colourscheme pieces. `install.sh`
links every one of these files individually into `~/.config/nvim/`, the same
per-file linking every other entry under `dotfiles/` gets.

## If you already have an nvim config

Anything already at one of those paths — your own `init.lua`,
`lua/config.lua`, etc. — is backed up to `<path>.bak-YYYYmmdd-HHMMSS` before
the link is made, the same generic rule every other `dotfiles/` target
follows (see [Installing over an existing
config](../installation/existing-config.md)). Unlike round-1 of this rice,
`install.sh` no longer treats `init.lua` as off-limits and prints lines to
add by hand — it replaces it outright (after backing yours up), since the
config is now this repo's to own end to end.

## Toolchain and plugins

`install.sh` offers the toolchain the bundled plugins need, all as
**optional** dependencies (skip `nvim` itself and nothing else needs them
either): `nodejs22` + `nodejs22-npm-bin` (Mason's `node`/`npm`, for
`pyright`, `svelte-language-server`, `@biomejs/biome`), `python3-pip`
(`MasonInstall clang-format`), `unzip` (Mason's GitHub-release downloads),
`ripgrep` + `fd-find` (telescope.nvim's grep/file-finder), a C/C++ toolchain
(`gcc`, `gcc-c++`, `make` — treesitter's `:TSUpdate` and
telescope-fzf-native's `build = make` both compile), `git`, and `golang`
(`gopls` via `go install`).

Once the config itself is linked, a later step runs the plugin manager
headless so the first real launch isn't a plugin download in the middle of
typing:

```bash
nvim --headless "+Lazy! restore" +qa
```

Guarded, never fatal: it first checks `git`, `gcc`, `g++` and `make` are on
`PATH` (warning per missing one rather than skipping the whole step — Lazy
still runs and does what it can), then this one command syncs every plugin
to the version pinned in `lazy-lock.json`. If it fails (slow link, a missing
toolchain piece, a plugin that needs a piece not listed above), nvim just
falls back to installing everything itself on its own next launch, exactly
as it always has. See
[What install.sh does](../installation/what-install-does.md#9-nvim-plugins-headless)
for where this sits relative to config linking.

## Matugen colourscheme

- `matugen/colorscheme.lua` — the matugen template. Rendered on every
  wallpaper switch to `~/.config/nvim/colors/matugen.lua`, a full Neovim
  colourscheme covering editor UI, base syntax groups, Treesitter captures,
  LSP semantic tokens, diagnostics, and the specific plugins this config
  actually uses (nvim-cmp, telescope.nvim, toggleterm.nvim, oil.nvim,
  harpoon2, todo-comments.nvim) plus the 16 ANSI terminal colours.
- `lua/matugen_watch.lua` — live-reload for the file above. Watches
  `~/.config/nvim/colors/` with `vim.uv.fs_event` and re-sources
  `colorscheme.lua` in every running Neovim instance, **only** while
  `matugen` is still the active colourscheme (running `:colorscheme
  gruvbox-material` by hand opts you out until you switch back). Debounced
  150ms so a render caught mid-write doesn't reload a half-written file.
  Wired up by `init.lua` (`require("matugen_watch")` +
  `pcall(vim.cmd.colorscheme, "matugen")`) — no manual step needed now that
  `init.lua` ships with the repo.
