return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    opts = {
      hooks = {
        -- Stronger diff colors inside Diffview only; the rest of Neovim keeps Carbonfox's.
        view_opened = function()
          vim.api.nvim_set_hl(0, "DiffviewDiffAdd", { bg = "#1f4a2e" })
          vim.api.nvim_set_hl(0, "DiffviewDiffDelete", { bg = "#4a1f2a", fg = "#6e3a46" })
          vim.api.nvim_set_hl(0, "DiffviewDiffChange", { bg = "#1f2f45" })
          vim.api.nvim_set_hl(0, "DiffviewDiffText", { bg = "#2f5580" })
        end,
      },
    },
  },
}
