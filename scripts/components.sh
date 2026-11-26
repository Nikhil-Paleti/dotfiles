# Shared command-to-formula mapping; no versions or pins.
# shellcheck disable=SC2034 # read by scripts/lib/common.sh and scripts/update.sh
requirements=(git:git jj:jj gh:gh curl:curl bazelisk:bazelisk nvim:neovim rg:ripgrep fd:fd
  lazygit:lazygit fzf:fzf atuin:atuin starship:starship tree-sitter:tree-sitter-cli python3:python uv:uv node:node
  npm:node stylua:stylua shfmt:shfmt shellcheck:shellcheck ruff:ruff)
