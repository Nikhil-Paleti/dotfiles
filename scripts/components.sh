# Every Homebrew formula the installer manages, as command:formula, in the groups install.sh
# installs them in. scripts/update.sh upgrades all of them. No versions or pins.
# shellcheck disable=SC2034 # read by install.sh and the scripts it sources
core_tools=(git:git jj:jj gh:gh curl:curl bazelisk:bazelisk)
editor_tools=(nvim:neovim)
search_tools=(rg:ripgrep fd:fd lazygit:lazygit fzf:fzf)
language_tools=(python3:python uv:uv node:node npm:node)
format_tools=(tree-sitter:tree-sitter-cli stylua:stylua shfmt:shfmt shellcheck:shellcheck ruff:ruff)
shell_tools=(atuin:atuin starship:starship zoxide:zoxide)
# zsh only (scripts/install/shell.sh). These formulas have no command, so that part is empty.
zsh_plugins=(:zsh-autosuggestions :zsh-syntax-highlighting)
requirements=("${core_tools[@]}" "${editor_tools[@]}" "${search_tools[@]}" "${language_tools[@]}"
  "${format_tools[@]}" "${shell_tools[@]}" "${zsh_plugins[@]}")
