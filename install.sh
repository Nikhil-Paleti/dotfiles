#!/usr/bin/env bash
# Install missing tools and apply repo Neovim and tmux configs from the repo.
# Usage: bash install.sh [--install|--update|--help]
# --install installs missing tools and replaces Neovim and tmux configs.
# --update upgrades installed managed Homebrew tools and replaces both configs.
# No argument shows help. Run as a normal user; system setup may request sudo.
set -euo pipefail
DOTFILES_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
[[ $# -le 1 ]] || { echo 'Only one argument is supported.' >&2; exit 2; }
case "${1:---help}" in
  --install) mode=install ;;
  --update) mode=update ;;
  -h|--help) sed -n '2,6p' "$DOTFILES_ROOT/install.sh"; exit 0 ;;
  *) echo 'Usage: bash install.sh [--install|--update|--help]' >&2; exit 2 ;;
esac
# Modules are sourced in one process so PATH discovery and owned-temp cleanup
# remain available across steps. Invoke this entry point, not modules directly.
source "$DOTFILES_ROOT/scripts/lib/common.sh"
source "$DOTFILES_ROOT/scripts/platform.sh"
source "$DOTFILES_ROOT/scripts/discover.sh"
source "$DOTFILES_ROOT/scripts/components.sh"
# Install missing tools or upgrade installed tools, then apply canonical configs.
source "$DOTFILES_ROOT/scripts/lib/temp.sh"
if [[ "$mode" == update ]]; then
  source "$DOTFILES_ROOT/scripts/update.sh"
else
  source "$DOTFILES_ROOT/scripts/install/prerequisites.sh"
  source "$DOTFILES_ROOT/scripts/install/homebrew.sh"
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
  source "$DOTFILES_ROOT/scripts/install/core.sh"
  install_tool "tmux" tmux
  source "$DOTFILES_ROOT/scripts/install/neovim.sh"
  source "$DOTFILES_ROOT/scripts/install/search.sh"
  source "$DOTFILES_ROOT/scripts/install/runtimes.sh"
  source "$DOTFILES_ROOT/scripts/install/formatters.sh"
fi
echo 'Applying repo configs without backups; local-only edits will be overwritten.'
source "$DOTFILES_ROOT/scripts/install/tmux.sh"
source "$DOTFILES_ROOT/scripts/install/lazyvim.sh"
printf '\nRepo Neovim and tmux configs applied.\n'
if [[ "$mode" == install ]]; then
  echo 'Homebrew is configured for future shells. Open a new terminal, or run this in the current one:'
  printf 'eval "$("%s" shellenv)"\n' "$(command -v brew)"
fi
echo 'Start nvim to install plugins, then run :LazyHealth. Language extras remain feature-specific.'
