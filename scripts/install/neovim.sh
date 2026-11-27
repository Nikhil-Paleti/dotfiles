# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
install_tools Neovim "${editor_tools[@]}"
# LazyVim needs Neovim 0.11.2+ with LuaJIT. Probe without user config, plugins, swap or ShaDa.
nvim --headless -u NONE -i NONE --noplugin -n \
  -c 'lua if vim.fn.has("nvim-0.11.2") ~= 1 or type(jit) ~= "table" then os.exit(1) end' \
  -c 'qa!' ||
  die "Neovim at $(command -v nvim) is not 0.11.2+ with LuaJIT, or cannot start headless." \
    'Upgrade it with the package manager that installed it (Homebrew: brew upgrade neovim), then rerun.' \
    'The Neovim config was not replaced.'
