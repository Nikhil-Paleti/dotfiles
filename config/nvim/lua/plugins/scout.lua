-- scout: indexed code search (github.com/Nikhil-Paleti/scout). Run :ScoutIndex once in a
-- repo; from then on LazyVim's grep keys (Space /, Space s g, Space s w) search scout's index
-- there. Repos without an index keep the Snacks picker's ripgrep, and file search
-- (Space Space, Space f f) stays on Snacks everywhere. Indexes live in ~/.cache/scout on this
-- machine only; nothing is uploaded. :checkhealth scout shows the binary and index state.
--
-- install.sh builds the `scout` binary with cargo at the commit lazy-lock.json pins below, so
-- the Lua and the binary always match. lazy.nvim doesn't build it (no `build` step), so
-- :Lazy update never compiles Rust inside Neovim.
return {
  {
    "Nikhil-Paleti/scout",
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
