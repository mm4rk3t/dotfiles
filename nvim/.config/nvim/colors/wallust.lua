-- ~/.config/nvim/colors/wallust.lua
-- Static file, does NOT get overwritten by wallust. It reads the
-- auto-generated palette table at lua/theme/wallust.lua every time
-- the colorscheme is (re)applied, so ":colorscheme wallust" always
-- picks up the latest wallpaper-derived colors.

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.g.colors_name = "wallust"

-- force a fresh require every time (so :colorscheme wallust reloads it
-- live instead of using nvim's module cache from last wallpaper change)
package.loaded["theme.wallust"] = nil
local c = require("theme.wallust")

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Base editor surface
hi("Normal",       { fg = c.fg, bg = c.bg })
hi("NormalFloat",  { fg = c.fg, bg = c.black })
hi("CursorLine",   { bg = c.black })
hi("CursorLineNr", { fg = c.bmagenta, bold = true })
hi("LineNr",       { fg = c.gray })
hi("SignColumn",   { bg = c.bg })
hi("VertSplit",    { fg = c.gray })
hi("Visual",       { bg = c.color0 and c.gray or c.gray, reverse = true })
hi("Search",       { fg = c.bg, bg = c.byellow })
hi("IncSearch",    { fg = c.bg, bg = c.bred })
hi("Pmenu",        { fg = c.fg, bg = c.black })
hi("PmenuSel",     { fg = c.bg, bg = c.bmagenta })
hi("StatusLine",   { fg = c.fg, bg = c.black })
hi("StatusLineNC", { fg = c.gray, bg = c.black })

-- Gothic-leaning syntax: cool blues/purples for structure, blood-red for
-- keywords/errors, muted everything else -- avoids the "rainbow pywal"
-- look even when the wallpaper itself has bright colors in it.
hi("Comment",    { fg = c.gray, italic = true })
hi("Constant",   { fg = c.bmagenta })
hi("String",     { fg = c.green })
hi("Identifier", { fg = c.cyan })
hi("Function",   { fg = c.blue, bold = true })
hi("Statement",  { fg = c.red, bold = true })
hi("Keyword",    { fg = c.magenta, bold = true })
hi("Type",       { fg = c.bblue })
hi("Special",    { fg = c.bcyan })
hi("Underlined", { fg = c.blue, underline = true })
hi("Error",      { fg = c.white, bg = c.red, bold = true })
hi("Todo",       { fg = c.bg, bg = c.byellow, bold = true })

-- Diagnostics (LSP)
hi("DiagnosticError", { fg = c.red })
hi("DiagnosticWarn",  { fg = c.yellow })
hi("DiagnosticInfo",  { fg = c.blue })
hi("DiagnosticHint",  { fg = c.cyan })
