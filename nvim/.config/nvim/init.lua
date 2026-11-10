-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("lazy").setup({
  {
    "RedsXDD/neopywal.nvim",
    name = "neopywal",
    lazy = false,
    priority = 1000,
    },
})

require("neopywal").setup({
    -- The live reloader posts a multi-line info message on every theme switch,
    -- which forces a hit-enter prompt; keep only warnings and errors
    notify = "warn",
    use_palette = {
        dark = "wallust",
        light = "tokyonight"
    }
})

vim.cmd.colorscheme("neopywal")
vim.opt.number = true

-- Live-reload colors in every open nvim when wallust regenerates the palette.
-- Neopywal's own reloader watches the file itself and loses track of it when
-- wallust replaces the file; watching the directory survives that.
do
  local dir = vim.fn.expand("~/.cache/wallust")
  local target = "colors_neopywal.vim"
  local watcher = vim.uv.new_fs_event()
  local timer = vim.uv.new_timer()
  if watcher and timer then
    watcher:start(dir, {}, function(err, filename)
      if err or filename ~= target then return end
      -- debounce: wallust may write the file in several steps
      timer:stop()
      timer:start(200, 0, vim.schedule_wrap(function()
        if (vim.g.colors_name or ""):match("^neopywal") then
          require("neopywal.lib.compiler").recompile(false)
        end
      end))
    end)
  end
end
