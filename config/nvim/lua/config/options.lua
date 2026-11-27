-- Loaded before lazy.nvim starts, on top of LazyVim's defaults (lazyvim/config/options.lua).

-- Yanks go to your local clipboard through the terminal (OSC 52). p pastes Neovim's own last
-- yank: most terminals never answer an OSC 52 read, so asking would hang p for ~10s.
do
  local osc52 = require("vim.ui.clipboard.osc52")
  local last = {} -- register name -> { lines, regtype } of the last yank into it

  local function copy(reg)
    local send = osc52.copy(reg)
    return function(lines, regtype)
      last[reg] = { vim.deepcopy(lines), regtype }
      send(lines)
    end
  end

  local function paste(reg)
    return function()
      return last[reg] or { {}, "v" }
    end
  end

  vim.g.clipboard = {
    name = "osc52-copy",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
  }
end

-- Rounded borders on floating windows (hover docs, signature help, diagnostics).
vim.o.winborder = "rounded"

-- Keep Neovim's built-in file browser (netrw) off, so `nvim .` opens the start screen
-- instead of a folder listing.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Never format on save (projects like work bring their own formatters). Linters still
-- run, and Space c f formats the current file on demand with its usual formatter.
vim.g.autoformat = false

-- No plugin here uses Neovim's Perl, Ruby, Node, or Python bridges; skip loading them.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
