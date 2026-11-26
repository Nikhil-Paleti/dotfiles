-- Plugins that LazyVim's language extras add but this setup doesn't use.
return {
  -- Browser preview for markdown: WSL sessions here can't open a browser, and notes
  -- already render inside Neovim (render-markdown, Space u m).
  { "iamcco/markdown-preview.nvim", enabled = false },
  -- Virtualenv switcher: Python environments come from Bazel via pyrightconfig.json.
  { "linux-cultist/venv-selector.nvim", enabled = false },
}
