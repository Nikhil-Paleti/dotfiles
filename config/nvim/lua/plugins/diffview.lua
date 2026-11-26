return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewRefresh", "DiffviewFileHistory" },
    -- Space g v is free in LazyVim (Space g d and Space g r are taken).
    keys = {
      { "<leader>gv", "", desc = "+diffview" },
      { "<leader>gvo", "<cmd>DiffviewOpen<cr>", desc = "Open" },
      { "<leader>gvc", "<cmd>DiffviewClose<cr>", desc = "Close" },
      { "<leader>gvr", "<cmd>DiffviewRefresh<cr>", desc = "Refresh" },
      { "<leader>gvh", "<cmd>DiffviewFileHistory %<cr>", desc = "Current File History" },
    },
    opts = {
      hooks = {
        -- Stronger diff colors inside Diffview only; the rest of Neovim keeps Carbonfox's.
        view_opened = function()
          vim.api.nvim_set_hl(0, "DiffviewDiffAdd", { bg = "#1f4a2e" })
          vim.api.nvim_set_hl(0, "DiffviewDiffDelete", { bg = "#4a1f2a", fg = "#6e3a46" })
          vim.api.nvim_set_hl(0, "DiffviewDiffChange", { bg = "#1f2f45" })
          vim.api.nvim_set_hl(0, "DiffviewDiffText", { bg = "#2f5580" })
        end,
        -- Old versions are read from git, not disk, so language servers can't resolve their
        -- imports and flag everything. Hide diagnostics there; the working copy keeps them.
        diff_buf_read = function(bufnr)
          -- This hook also fires for the real file on disk; leave that one alone.
          if vim.api.nvim_buf_get_name(bufnr):match("^diffview://") then
            vim.diagnostic.enable(false, { bufnr = bufnr })
          end
        end,
      },
    },
  },
}
