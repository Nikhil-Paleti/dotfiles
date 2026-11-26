return {
  -- cuda builds on cpp, so both parsers are needed for .cu/.cuh highlighting.
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "cpp", "cuda" } } },
}
