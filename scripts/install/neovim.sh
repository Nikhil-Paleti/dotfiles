##### Neovim install #####
install_tool "Neovim" nvim
# Probe without loading user config, plugins, swap files, or ShaDa.
if ! nvim --headless -u NONE -i NONE --noplugin -n \
  -c 'lua if vim.fn.has("nvim-0.11.2") ~= 1 or type(jit) ~= "table" then os.exit(1) end' \
  -c 'qa!'; then
  printf 'Neovim at %s could not pass the LazyVim compatibility check.\n' "$(command -v nvim)" >&2
  echo 'Required: Neovim >= 0.11.2 built with LuaJIT, and a working headless startup.' >&2
  echo 'Upgrade Neovim with its current package manager, or explicitly install a compatible build.' >&2
  echo 'For Homebrew: brew install neovim (or brew upgrade neovim if already installed).' >&2
  echo 'Check command -v nvim and nvim --version, then rerun bash install.sh.' >&2
  echo 'Neovim config has not been replaced by this run.' >&2
  exit 1
fi
##### end Neovim install #####
