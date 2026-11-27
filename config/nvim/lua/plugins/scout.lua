-- scout: indexed code search (github.com/Nikhil-Paleti/scout). Indexes git repos on open and
-- takes over LazyVim's grep and file keys once a repo is indexed. install.sh keeps its checkout
-- and build in the dotfiles' modules/scout and writes lua/dotfiles_root.lua; lazy.nvim doesn't
-- manage it, so rerun install.sh to update. :checkhealth scout shows its state.
local ok, dotfiles_root = pcall(require, "dotfiles_root")
local scout_dir = (ok and type(dotfiles_root) == "string" and dotfiles_root or "") .. "/modules/scout"

return {
  {
    dir = scout_dir,
    name = "scout",
    cond = (vim.uv or vim.loop).fs_stat(scout_dir .. "/lua/scout/init.lua") ~= nil,
    -- After the start screen draws; setup then starts the indexer in the background.
    event = "VeryLazy",
    -- Free keys in LazyVim's search group; y and x take the word under the cursor (callers
    -- are matched by name), . searches the current file's folder.
    keys = {
      { "<leader>sy", "<cmd>ScoutSym<cr>", desc = "Definitions (scout)" },
      { "<leader>sx", "<cmd>ScoutCallers<cr>", desc = "Callers (scout)" },
      { "<leader>s.", "<cmd>ScoutDir<cr>", desc = "Grep File's Folder (scout)" },
    },
    opts = {},
  },
}
