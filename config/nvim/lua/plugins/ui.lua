return {
  -- noice draws hover docs (K) and signature help itself, so 'winborder' doesn't reach them.
  { "folke/noice.nvim", opts = { presets = { lsp_doc_border = true } } },
  -- Show dotfiles (.bazelrc, .gitignore, ...) in file search, text search, and the explorer.
  -- Git-ignored files (bazel-*, .venv, ...) stay hidden; toggle them with Alt+i.
  {
    "folke/snacks.nvim",
    opts = {
      -- `nvim .` shows only the start screen; the explorer stays closed until Space e.
      -- (netrw, which would otherwise take over folders, is off in config/options.lua.)
      explorer = { replace_netrw = false },
      picker = {
        sources = {
          files = { hidden = true },
          grep = { hidden = true },
          explorer = { hidden = true },
        },
      },
    },
  },
}
