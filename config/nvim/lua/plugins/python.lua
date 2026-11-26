return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            python = {
              analysis = {
                -- Don't crawl Bazel's output symlinks (bazel-bin, bazel-out, ...), which can be
                -- huge in a monorepo. Imports from them still resolve. Setting this replaces
                -- Pyright's default skip list, so that list is repeated here.
                -- A project's own pyrightconfig.json or [tool.pyright] takes precedence.
                exclude = { "**/node_modules", "**/__pycache__", "**/.*", "**/bazel-*" },
              },
            },
          },
        },
      },
    },
  },
}
