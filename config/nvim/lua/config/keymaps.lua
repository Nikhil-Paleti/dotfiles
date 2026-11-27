-- Loaded on VeryLazy, on top of LazyVim's defaults (lazyvim/config/keymaps.lua).
-- Space h: back to the start screen (same scene as at startup; q closes it).
vim.keymap.set("n", "<leader>h", function()
  Snacks.dashboard()
end, { desc = "Home screen" })
