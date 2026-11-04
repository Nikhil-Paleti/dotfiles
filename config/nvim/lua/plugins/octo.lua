return {
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    event = { { event = "BufReadCmd", pattern = "octo://*" } },
    dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim" },
    opts = function()
      vim.treesitter.language.register("markdown", "octo")
      return { picker = "snacks", enable_builtin = true }
    end,
  },
}
