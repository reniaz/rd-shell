-- Rendered by matugen (~/.config/nvim/matugen/colorscheme.lua) via the
-- [templates.nvim] entry in ~/.config/matugen/config.toml, on every wallpaper
-- switch. Output goes to ~/.config/nvim/colors/matugen.lua, which Neovim's
-- 'runtimepath'/colors resolution loads for `:colorscheme matugen`. Running
-- instances live-reload themselves: lua/matugen_watch.lua (required from
-- init.lua) watches this output file with vim.uv.fs_event and re-sources it
-- only while it is the active colorscheme -- no post_hook, no --remote-send
-- typed into whatever buffer happens to be focused.
--
-- Mapping mirrors the matugen contract's canonical scheme:
--   bg = surface (always solid -- Hyprland's 85%-opacity/blur window rule
--   must never bleed into the editor), fg = on_surface.
--   Syntax uses the six harmonized custom_colors (red green yellow blue
--   magenta cyan) instead of on_*_container/primary tones, which collapse
--   onto bg on a one-hue tonal-spot wallpaper.
--   Comments/decorative UI = outline (checked >=4.5:1 / >=3:1, both modes).

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "matugen"
vim.o.background = "{{mode}}"
vim.o.termguicolors = true

local c = {
  bg = "{{colors.surface.default.hex}}",
  bg_dim = "{{colors.surface_dim.default.hex}}",
  bg_bright = "{{colors.surface_bright.default.hex}}",
  bg_low = "{{colors.surface_container_low.default.hex}}",
  bg_container = "{{colors.surface_container.default.hex}}",
  bg_high = "{{colors.surface_container_high.default.hex}}",
  bg_highest = "{{colors.surface_container_highest.default.hex}}",
  fg = "{{colors.on_surface.default.hex}}",
  fg_variant = "{{colors.on_surface_variant.default.hex}}",
  outline = "{{colors.outline.default.hex}}",
  outline_variant = "{{colors.outline_variant.default.hex}}",
  primary = "{{colors.primary.default.hex}}",
  on_primary = "{{colors.on_primary.default.hex}}",
  primary_container = "{{colors.primary_container.default.hex}}",
  on_primary_container = "{{colors.on_primary_container.default.hex}}",
  error = "{{colors.error.default.hex}}",
  on_error = "{{colors.on_error.default.hex}}",
  error_container = "{{colors.error_container.default.hex}}",
  on_error_container = "{{colors.on_error_container.default.hex}}",

  red = "{{colors.red.default.hex}}",
  on_red = "{{colors.on_red.default.hex}}",
  red_container = "{{colors.red_container.default.hex}}",
  on_red_container = "{{colors.on_red_container.default.hex}}",
  green = "{{colors.green.default.hex}}",
  on_green = "{{colors.on_green.default.hex}}",
  green_container = "{{colors.green_container.default.hex}}",
  on_green_container = "{{colors.on_green_container.default.hex}}",
  yellow = "{{colors.yellow.default.hex}}",
  on_yellow = "{{colors.on_yellow.default.hex}}",
  yellow_container = "{{colors.yellow_container.default.hex}}",
  on_yellow_container = "{{colors.on_yellow_container.default.hex}}",
  blue = "{{colors.blue.default.hex}}",
  on_blue = "{{colors.on_blue.default.hex}}",
  blue_container = "{{colors.blue_container.default.hex}}",
  on_blue_container = "{{colors.on_blue_container.default.hex}}",
  magenta = "{{colors.magenta.default.hex}}",
  on_magenta = "{{colors.on_magenta.default.hex}}",
  magenta_container = "{{colors.magenta_container.default.hex}}",
  on_magenta_container = "{{colors.on_magenta_container.default.hex}}",
  cyan = "{{colors.cyan.default.hex}}",
  on_cyan = "{{colors.on_cyan.default.hex}}",
  cyan_container = "{{colors.cyan_container.default.hex}}",
  on_cyan_container = "{{colors.on_cyan_container.default.hex}}",
}

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor UI
hi("Normal", { fg = c.fg, bg = c.bg })
hi("NormalNC", { fg = c.fg, bg = c.bg })
hi("NormalFloat", { fg = c.fg, bg = c.bg_high })
hi("FloatBorder", { fg = c.outline, bg = c.bg_high })
hi("FloatTitle", { fg = c.primary, bg = c.bg_high })
hi("FloatShadow", {})
hi("FloatShadowThrough", {})
hi("CursorLine", { bg = c.bg_container })
hi("CursorColumn", { bg = c.bg_container })
hi("Cursor", { fg = c.bg, bg = c.primary })
hi("TermCursor", { fg = c.bg, bg = c.primary })
hi("LineNr", { fg = c.outline })
hi("CursorLineNr", { fg = c.primary })
hi("SignColumn", { fg = c.outline, bg = c.bg })
hi("FoldColumn", { fg = c.outline, bg = c.bg })
hi("Folded", { fg = c.fg_variant, bg = c.bg_container })
hi("Visual", { bg = c.primary_container, fg = c.on_primary_container })
hi("VisualNOS", { bg = c.primary_container, fg = c.on_primary_container })
hi("Search", { bg = c.yellow_container, fg = c.on_yellow_container })
hi("IncSearch", { bg = c.yellow, fg = c.on_yellow })
hi("CurSearch", { bg = c.yellow, fg = c.on_yellow })
hi("Substitute", { bg = c.red_container, fg = c.on_red_container })
hi("StatusLine", { fg = c.fg, bg = c.bg_high })
hi("StatusLineNC", { fg = c.outline, bg = c.bg_container })
-- Set explicitly because nvim's own defaults for these are bold, and hi clear
-- falls back to them; the theme has no bold anywhere.
hi("WinBar", { fg = c.fg, bg = c.bg })
hi("WinBarNC", { fg = c.outline, bg = c.bg })
-- outline_variant measured under 3:1 against bg in both modes (this is a
-- decorative divider, but that's still too low to read against surface) --
-- use outline, which clears the 3:1 decorative floor in both modes.
hi("WinSeparator", { fg = c.outline, bg = c.bg })
hi("VertSplit", { fg = c.outline, bg = c.bg })
hi("Pmenu", { fg = c.fg, bg = c.bg_high })
hi("PmenuSel", { fg = c.on_primary_container, bg = c.primary_container })
hi("PmenuMatch", { fg = c.primary, bg = c.bg_high })
hi("PmenuMatchSel", { fg = c.on_primary_container, bg = c.primary_container })
hi("PmenuSbar", { bg = c.bg_container })
hi("PmenuThumb", { bg = c.outline })
hi("PmenuKind", { fg = c.blue, bg = c.bg_high })
hi("PmenuKindSel", { fg = c.blue, bg = c.primary_container })
hi("PmenuExtra", { fg = c.fg_variant, bg = c.bg_high })
hi("PmenuExtraSel", { fg = c.fg_variant, bg = c.primary_container })
hi("TabLine", { fg = c.fg_variant, bg = c.bg_container })
hi("TabLineFill", { bg = c.bg_container })
hi("TabLineSel", { fg = c.on_primary_container, bg = c.primary_container })
hi("MatchParen", { fg = c.on_primary_container, bg = c.primary_container })
hi("NonText", { fg = c.outline })
hi("Whitespace", { fg = c.outline })
hi("SpecialKey", { fg = c.outline })
hi("EndOfBuffer", { fg = c.bg })
hi("ColorColumn", { bg = c.bg_container })
hi("Directory", { fg = c.blue })
hi("Title", { fg = c.primary })
hi("ModeMsg", { fg = c.fg })
hi("MoreMsg", { fg = c.green })
hi("Question", { fg = c.green })
hi("WarningMsg", { fg = c.yellow })
hi("ErrorMsg", { fg = c.error })
hi("WildMenu", { fg = c.on_primary_container, bg = c.primary_container })
hi("QuickFixLine", { bg = c.bg_container })

-- Diff / (git signs groups kept for parity even though gitsigns isn't used)
hi("DiffAdd", { bg = c.green_container, fg = c.on_green_container })
hi("DiffChange", { bg = c.yellow_container, fg = c.on_yellow_container })
hi("DiffDelete", { bg = c.red_container, fg = c.on_red_container })
hi("DiffText", { bg = c.blue_container, fg = c.on_blue_container })
hi("GitSignsAdd", { fg = c.green })
hi("GitSignsChange", { fg = c.yellow })
hi("GitSignsDelete", { fg = c.red })

-- Base syntax groups
-- outline measured at 4.27:1 against bg in --mode light (under the 4.5:1
-- text floor); on_surface_variant (fg_variant) clears 4.5:1 in both modes,
-- so comments use it instead.
hi("Comment", { fg = c.fg_variant })
hi("Constant", { fg = c.cyan })
hi("String", { fg = c.green })
hi("Character", { fg = c.green })
hi("Number", { fg = c.magenta })
hi("Boolean", { fg = c.magenta })
hi("Float", { fg = c.magenta })
hi("Identifier", { fg = c.fg })
hi("Function", { fg = c.blue })
hi("Statement", { fg = c.red })
hi("Conditional", { fg = c.red })
hi("Repeat", { fg = c.red })
hi("Label", { fg = c.red })
hi("Operator", { fg = c.fg_variant })
hi("Keyword", { fg = c.red })
hi("Exception", { fg = c.red })
hi("PreProc", { fg = c.cyan })
hi("Include", { fg = c.cyan })
hi("Define", { fg = c.cyan })
hi("Macro", { fg = c.cyan })
hi("Type", { fg = c.yellow })
hi("StorageClass", { fg = c.yellow })
hi("Structure", { fg = c.yellow })
hi("Typedef", { fg = c.yellow })
hi("Special", { fg = c.blue })
hi("SpecialChar", { fg = c.blue })
hi("Tag", { fg = c.blue })
hi("Delimiter", { fg = c.fg_variant })
hi("SpecialComment", { fg = c.fg_variant })
hi("Underlined", { fg = c.blue, underline = true })
hi("Ignore", { fg = c.outline })
hi("Error", { fg = c.on_error_container, bg = c.error_container })
hi("Todo", { fg = c.on_yellow_container, bg = c.yellow_container })

-- Treesitter @captures
hi("@variable", { fg = c.fg })
hi("@variable.builtin", { fg = c.magenta })
hi("@variable.parameter", { fg = c.fg_variant })
hi("@variable.member", { fg = c.cyan })
hi("@constant", { fg = c.cyan })
hi("@constant.builtin", { fg = c.magenta })
hi("@constant.macro", { fg = c.cyan })
hi("@module", { fg = c.yellow })
hi("@label", { fg = c.red })
hi("@string", { fg = c.green })
hi("@string.escape", { fg = c.magenta })
hi("@string.regexp", { fg = c.magenta })
hi("@string.special", { fg = c.blue })
hi("@character", { fg = c.green })
hi("@character.special", { fg = c.blue })
hi("@number", { fg = c.magenta })
hi("@boolean", { fg = c.magenta })
hi("@float", { fg = c.magenta })
hi("@function", { fg = c.blue })
hi("@function.builtin", { fg = c.blue })
hi("@function.macro", { fg = c.cyan })
hi("@function.method", { fg = c.blue })
hi("@constructor", { fg = c.yellow })
hi("@operator", { fg = c.fg_variant })
hi("@keyword", { fg = c.red })
hi("@keyword.function", { fg = c.red })
hi("@keyword.operator", { fg = c.red })
hi("@keyword.return", { fg = c.red })
hi("@keyword.import", { fg = c.red })
hi("@conditional", { fg = c.red })
hi("@repeat", { fg = c.red })
hi("@exception", { fg = c.red })
hi("@type", { fg = c.yellow })
hi("@type.builtin", { fg = c.yellow })
hi("@type.definition", { fg = c.yellow })
hi("@attribute", { fg = c.cyan })
hi("@property", { fg = c.cyan })
hi("@punctuation.delimiter", { fg = c.fg_variant })
hi("@punctuation.bracket", { fg = c.fg_variant })
hi("@punctuation.special", { fg = c.blue })
hi("@comment", { fg = c.fg_variant })
hi("@comment.documentation", { fg = c.fg_variant })
hi("@tag", { fg = c.blue })
hi("@tag.attribute", { fg = c.cyan })
hi("@tag.delimiter", { fg = c.fg_variant })
hi("@markup.heading", { fg = c.primary })
hi("@markup.strong", { fg = c.fg })
hi("@markup.italic", { fg = c.fg })
hi("@markup.link", { fg = c.blue, underline = true })
hi("@markup.link.url", { fg = c.cyan, underline = true })
hi("@markup.raw", { fg = c.green })
hi("@markup.list", { fg = c.red })

-- LSP semantic tokens (linked onto the treesitter captures above)
hi("@lsp.type.class", { link = "@type" })
hi("@lsp.type.decorator", { link = "@attribute" })
hi("@lsp.type.enum", { link = "@type" })
hi("@lsp.type.enumMember", { link = "@constant" })
hi("@lsp.type.function", { link = "@function" })
hi("@lsp.type.interface", { link = "@type" })
hi("@lsp.type.macro", { link = "@function.macro" })
hi("@lsp.type.method", { link = "@function.method" })
hi("@lsp.type.namespace", { link = "@module" })
hi("@lsp.type.parameter", { link = "@variable.parameter" })
hi("@lsp.type.property", { link = "@property" })
hi("@lsp.type.struct", { link = "@type" })
hi("@lsp.type.type", { link = "@type" })
hi("@lsp.type.typeParameter", { link = "@type.definition" })
hi("@lsp.type.variable", { link = "@variable" })
hi("@lsp.mod.readonly", {})
hi("@lsp.mod.deprecated", { strikethrough = true })

-- Diagnostics
hi("DiagnosticError", { fg = c.error })
hi("DiagnosticWarn", { fg = c.yellow })
hi("DiagnosticInfo", { fg = c.blue })
hi("DiagnosticHint", { fg = c.cyan })
hi("DiagnosticOk", { fg = c.green })
hi("DiagnosticVirtualTextError", { fg = c.error, bg = c.error_container })
hi("DiagnosticVirtualTextWarn", { fg = c.on_yellow_container, bg = c.yellow_container })
hi("DiagnosticVirtualTextInfo", { fg = c.on_blue_container, bg = c.blue_container })
hi("DiagnosticVirtualTextHint", { fg = c.on_cyan_container, bg = c.cyan_container })
hi("DiagnosticVirtualTextOk", { fg = c.on_green_container, bg = c.green_container })
hi("DiagnosticUnderlineError", { sp = c.error, underline = true })
hi("DiagnosticUnderlineWarn", { sp = c.yellow, underline = true })
hi("DiagnosticUnderlineInfo", { sp = c.blue, underline = true })
hi("DiagnosticUnderlineHint", { sp = c.cyan, underline = true })
hi("DiagnosticUnderlineOk", { sp = c.green, underline = true })
hi("DiagnosticSignError", { fg = c.error, bg = c.bg })
hi("DiagnosticSignWarn", { fg = c.yellow, bg = c.bg })
hi("DiagnosticSignInfo", { fg = c.blue, bg = c.bg })
hi("DiagnosticSignHint", { fg = c.cyan, bg = c.bg })
hi("DiagnosticSignOk", { fg = c.green, bg = c.bg })
hi("DiagnosticFloatingError", { fg = c.error, bg = c.bg_high })
hi("DiagnosticFloatingWarn", { fg = c.yellow, bg = c.bg_high })
hi("DiagnosticFloatingInfo", { fg = c.blue, bg = c.bg_high })
hi("DiagnosticFloatingHint", { fg = c.cyan, bg = c.bg_high })
hi("DiagnosticFloatingOk", { fg = c.green, bg = c.bg_high })

-- Plugins actually used by this init.lua: nvim-cmp, telescope.nvim (+
-- fzf-native), toggleterm.nvim, oil.nvim, harpoon2, todo-comments.nvim,
-- nvim-highlight-colors, nvim-ts-autotag, nvim-autopairs, auto-session,
-- Comment.nvim, lazydev.nvim. No lualine, gitsigns, which-key,
-- indent-blankline, snacks or blink.cmp in this config -- their groups are
-- intentionally left out.

-- nvim-cmp (Pmenu* above covers the popup; these are the item-kind bits)
hi("CmpItemAbbr", { fg = c.fg })
hi("CmpItemAbbrMatch", { fg = c.primary })
hi("CmpItemAbbrMatchFuzzy", { fg = c.primary })
hi("CmpItemAbbrDeprecated", { fg = c.outline, strikethrough = true })
hi("CmpItemKind", { fg = c.blue })
hi("CmpItemMenu", { fg = c.fg_variant })

-- telescope.nvim: the gruvbox-material plugin spec overrides
-- TelescopeNormal/TelescopeBorder with hardcoded hexes *after* calling
-- `:colorscheme gruvbox-material` in its own config function; this
-- colorscheme's `hi clear` wipes those overrides when matugen becomes
-- active, so telescope needs its own groups here or it would fall back to
-- unstyled white-on-black.
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_high })
hi("TelescopeBorder", { fg = c.outline, bg = c.bg_high })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_container })
hi("TelescopePromptBorder", { fg = c.outline, bg = c.bg_container })
hi("TelescopePromptTitle", { fg = c.on_primary_container, bg = c.primary_container })
hi("TelescopeResultsTitle", { fg = c.on_primary_container, bg = c.primary_container })
hi("TelescopePreviewTitle", { fg = c.on_green_container, bg = c.green_container })
hi("TelescopeSelection", { fg = c.on_primary_container, bg = c.primary_container })
hi("TelescopeSelectionCaret", { fg = c.primary, bg = c.primary_container })
hi("TelescopeMatching", { fg = c.primary })
hi("TelescopeMultiSelection", { fg = c.on_green_container, bg = c.green_container })

-- toggleterm.nvim float border is told to reuse "Normal"/"Normal" directly
-- (highlights.border/background = "Normal" in init.lua) -- already covered.

-- oil.nvim
hi("OilDir", { fg = c.blue })
hi("OilDirIcon", { fg = c.blue })
hi("OilLink", { fg = c.cyan })
hi("OilLinkTarget", { fg = c.fg_variant })
hi("OilFile", { fg = c.fg })
hi("OilCreate", { fg = c.green })
hi("OilDelete", { fg = c.error })
hi("OilMove", { fg = c.yellow })
hi("OilCopy", { fg = c.blue })
hi("OilChange", { fg = c.yellow })
hi("OilRestore", { fg = c.cyan })
hi("OilPurge", { fg = c.error })
hi("OilTrash", { fg = c.outline })

-- harpoon2's list UI is a plain float; NormalFloat/FloatBorder above cover it.

-- todo-comments.nvim (opts = { signs = false }, so only the in-text
-- highlight groups matter -- no TodoSign* needed)
hi("TodoBgTODO", { fg = c.bg, bg = c.blue })
hi("TodoFgTODO", { fg = c.blue })
hi("TodoBgFIX", { fg = c.bg, bg = c.red })
hi("TodoFgFIX", { fg = c.red })
hi("TodoBgHACK", { fg = c.bg, bg = c.yellow })
hi("TodoFgHACK", { fg = c.yellow })
hi("TodoBgWARN", { fg = c.bg, bg = c.yellow })
hi("TodoFgWARN", { fg = c.yellow })
hi("TodoBgPERF", { fg = c.bg, bg = c.magenta })
hi("TodoFgPERF", { fg = c.magenta })
hi("TodoBgNOTE", { fg = c.bg, bg = c.green })
hi("TodoFgNOTE", { fg = c.green })
hi("TodoBgTEST", { fg = c.bg, bg = c.cyan })
hi("TodoFgTEST", { fg = c.cyan })

-- ANSI terminal colours (toggleterm buffers, plain :terminal). Canonical
-- mapping from the matugen contract.
vim.g.terminal_color_0 = c.bg_high
vim.g.terminal_color_1 = c.red
vim.g.terminal_color_2 = c.green
vim.g.terminal_color_3 = c.yellow
vim.g.terminal_color_4 = c.blue
vim.g.terminal_color_5 = c.magenta
vim.g.terminal_color_6 = c.cyan
vim.g.terminal_color_7 = c.fg_variant
vim.g.terminal_color_8 = c.outline
vim.g.terminal_color_9 = c.on_red_container
vim.g.terminal_color_10 = c.on_green_container
vim.g.terminal_color_11 = c.on_yellow_container
vim.g.terminal_color_12 = c.on_blue_container
vim.g.terminal_color_13 = c.on_magenta_container
vim.g.terminal_color_14 = c.on_cyan_container
vim.g.terminal_color_15 = c.fg
