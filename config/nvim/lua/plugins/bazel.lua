-- Neovim doesn't detect .bazelrc files (.bazelrc, user.bazelrc, ...) on its own.
vim.filetype.add({ pattern = { [".*%.bazelrc"] = "bazelrc" } })

return {
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "starlark" } } },
  { "neovim/nvim-lspconfig", opts = { servers = { starpls = {}, bazelrc_lsp = {} } } },
  { "mason-org/mason.nvim", opts = { ensure_installed = { "buildifier" } } },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { bzl = { "buildifier" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { bzl = { "buildifier" } } } },
}
