-- scout: indexed code search (github.com/Nikhil-Paleti/scout). Run :ScoutIndex once in a
-- repo; from then on LazyVim's grep keys (Space /, Space s g, Space s w) search scout's index
-- there. Repos without an index keep the Snacks picker's ripgrep, and file search
-- (Space Space, Space f f) stays on Snacks everywhere. Indexes live in ~/.cache/scout on this
-- machine only; nothing is uploaded. :checkhealth scout shows the binary and index state.
--
-- install.sh keeps a checkout of scout's main branch in ${XDG_DATA_HOME:-~/.local/share}/scout,
-- pulls it on every run, and builds the binary there. The plugin loads from that same folder,
-- so its Lua and the binary always come from one commit. lazy.nvim doesn't clone, update or
-- build it (and lazy-lock.json has no entry for it): rerun bash install.sh to update scout.
-- Before the first install.sh run the folder doesn't exist and the plugin is skipped.
local data = vim.env.XDG_DATA_HOME
local scout_dir = (data and data ~= "" and data or vim.fn.expand("~/.local/share")) .. "/scout"

return {
  {
    dir = scout_dir,
    name = "scout",
    cond = (vim.uv or vim.loop).fs_stat(scout_dir .. "/lua/scout/init.lua") ~= nil,
    -- After the start screen draws: setup only starts one background `scout status`.
    event = "VeryLazy",
    -- Space s y and Space s x are free in LazyVim's search group. Both use the word under
    -- the cursor; callers are matched by name, so same-named functions mix.
    keys = {
      { "<leader>sy", "<cmd>ScoutSym<cr>", desc = "Definitions (scout)" },
      { "<leader>sx", "<cmd>ScoutCallers<cr>", desc = "Callers (scout)" },
    },
    opts = {},
  },
}
