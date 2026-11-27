-- scout: indexed code search (github.com/Nikhil-Paleti/scout). Opening Neovim in a git repo
-- (or :cd into one) starts scout's background indexer: it builds the index if there is none and
-- catches up from git if there is. It runs detached at low priority and skips $HOME and folders
-- outside git. Once a repo is indexed, LazyVim's grep keys (Space /, Space s g, Space s w) and
-- file keys (Space Space, Space f f) use scout there; until then they stay on the Snacks picker.
-- Indexes live in ~/.cache/scout on this machine only; nothing is uploaded. :checkhealth scout
-- shows the binary and index state.
--
-- install.sh keeps a checkout of scout's main branch in the dotfiles folder's modules/scout
-- (git-ignored), pulls it on every run, and builds the binary there. The plugin loads from that
-- same folder, so its Lua and the binary always come from one commit. lazy.nvim doesn't clone,
-- update or build it (and lazy-lock.json has no entry for it): rerun bash install.sh to update
-- scout. install.sh writes lua/dotfiles_root.lua with the dotfiles path into the installed
-- config; without it, or before the folder exists, the plugin is skipped.
local ok, dotfiles_root = pcall(require, "dotfiles_root")
local scout_dir = (ok and type(dotfiles_root) == "string" and dotfiles_root or "") .. "/modules/scout"

return {
  {
    dir = scout_dir,
    name = "scout",
    cond = (vim.uv or vim.loop).fs_stat(scout_dir .. "/lua/scout/init.lua") ~= nil,
    -- Right after the start screen draws; setup then starts the indexer for this repo
    -- (scout's index_on_start, on by default) without blocking the editor.
    event = "VeryLazy",
    -- Free keys in LazyVim's search group. Space s y and Space s x use the word under the
    -- cursor; callers are matched by name, so same-named functions mix. Space s . is a live
    -- search limited to the current file's folder (Google Code Search's ".").
    keys = {
      { "<leader>sy", "<cmd>ScoutSym<cr>", desc = "Definitions (scout)" },
      { "<leader>sx", "<cmd>ScoutCallers<cr>", desc = "Callers (scout)" },
      { "<leader>s.", "<cmd>ScoutDir<cr>", desc = "Grep File's Folder (scout)" },
    },
    opts = {},
  },
}
