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

-- Plugin versions live in the repo's lazy-lock.json, not in this installed copy (install.sh
-- replaces it). :Lazy update then shows up as a diff to commit, and install.sh restores the
-- same versions on every machine. lua/dotfiles_root.lua is written by install.sh.
local ok, dotfiles_root = pcall(require, "dotfiles_root")
local lockfile = nil
if ok and type(dotfiles_root) == "string" and (vim.uv or vim.loop).fs_stat(dotfiles_root .. "/config/nvim") then
  lockfile = dotfiles_root .. "/config/nvim/lazy-lock.json"
end

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false, -- latest commit; many plugins' tagged releases are stale
  },
  lockfile = lockfile,
  install = { colorscheme = { "tokyonight", "habamax" } },
  -- No plugin here needs luarocks; this silences the health warning about it.
  rocks = { enabled = false },
  checker = {
    enabled = true, -- check for plugin updates in the background
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
