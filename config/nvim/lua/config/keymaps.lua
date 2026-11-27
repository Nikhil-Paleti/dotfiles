-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Space h: back to the start screen (same scene as at startup; q closes it).
vim.keymap.set("n", "<leader>h", function()
  Snacks.dashboard()
end, { desc = "Home screen" })
