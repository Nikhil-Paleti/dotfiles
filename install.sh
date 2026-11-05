#!/usr/bin/env bash
# Install missing tools, update managed tools, and apply repo Neovim/tmux configs.
# Usage: bash install.sh [--help]
# Run as a normal user; system setup may request sudo. Your default shell is unchanged.
set -euo pipefail
DOTFILES_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
[[ $# -le 1 ]] || { echo 'Only one argument is supported.' >&2; exit 2; }
case "${1:-}" in
  '') ;;
  -h|--help) sed -n '2,4p' "$DOTFILES_ROOT/install.sh"; exit 0 ;;
  *) echo 'Usage: bash install.sh [--help]' >&2; exit 2 ;;
esac
# Modules are sourced in one process so PATH discovery and owned-temp cleanup
# remain available across steps. Invoke this entry point, not modules directly.
source "$DOTFILES_ROOT/scripts/lib/common.sh"
source "$DOTFILES_ROOT/scripts/platform.sh"
source "$DOTFILES_ROOT/scripts/discover.sh"
source "$DOTFILES_ROOT/scripts/components.sh"
# Upgrade managed tools, install anything missing, then apply canonical configs.
source "$DOTFILES_ROOT/scripts/lib/temp.sh"
source "$DOTFILES_ROOT/scripts/install/prerequisites.sh"
source "$DOTFILES_ROOT/scripts/install/homebrew.sh"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
source "$DOTFILES_ROOT/scripts/update.sh"
source "$DOTFILES_ROOT/scripts/install/core.sh"
install_tool "tmux" tmux
install_tool "TUIOS" tuios
source "$DOTFILES_ROOT/scripts/install/neovim.sh"
source "$DOTFILES_ROOT/scripts/install/search.sh"
source "$DOTFILES_ROOT/scripts/install/runtimes.sh"
source "$DOTFILES_ROOT/scripts/install/formatters.sh"
echo 'Applying repo configs without backups; local-only edits will be overwritten.'
source "$DOTFILES_ROOT/scripts/install/tmux.sh"
source "$DOTFILES_ROOT/scripts/install/lazyvim.sh"
printf '\nRepo Neovim and tmux configs applied.\n'
echo 'Homebrew is configured for future shells. Open a new terminal, or run this in the current one:'
printf 'eval "$("%s" shellenv)"\n' "$(command -v brew)"
echo 'Start nvim to install plugins, then run :LazyHealth. Language extras remain feature-specific.'
