return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            python = {
              analysis = {
                -- Skip Bazel's huge output symlinks (imports from them still resolve). This
                -- replaces Pyright's default list, so that is repeated here.
                exclude = { "**/node_modules", "**/__pycache__", "**/.*", "**/bazel-*" },
              },
            },
          },
        },
      },
    },
  },
}
