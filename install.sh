#!/usr/bin/env bash
# Install missing tools and apply repo Neovim config with persistent backups.
# Usage: bash install.sh [--install|--update|--help]
# --install installs missing tools and backs up/replaces Neovim config.
# --update upgrades installed managed Homebrew tools; it does not change config.
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
# Keep terminal input available for setup prompts; update runs separately.
if [[ "$mode" == update ]]; then
  source "$DOTFILES_ROOT/scripts/update.sh"
  exit 0
fi
source "$DOTFILES_ROOT/scripts/install/prerequisites.sh"
source "$DOTFILES_ROOT/scripts/lib/temp.sh"
source "$DOTFILES_ROOT/scripts/install/homebrew.sh"
source "$DOTFILES_ROOT/scripts/install/shellenv.sh"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
source "$DOTFILES_ROOT/scripts/install/core.sh"
source "$DOTFILES_ROOT/scripts/install/tmux.sh"
source "$DOTFILES_ROOT/scripts/install/neovim.sh"
source "$DOTFILES_ROOT/scripts/install/search.sh"
source "$DOTFILES_ROOT/scripts/install/runtimes.sh"
source "$DOTFILES_ROOT/scripts/install/formatters.sh"
source "$DOTFILES_ROOT/scripts/install/shell.sh"
source "$DOTFILES_ROOT/scripts/install/lazyvim.sh"
printf '\nProvisioning finished. Repo Neovim config installed; previous config backed up if present.\n'
echo 'Homebrew is configured for future shells; open a new terminal to use it.'
echo 'Tools (including zsh and uv) are installed or reused; zsh plugins are installed but not enabled.'
echo 'Start nvim to install plugins, then run :LazyHealth. Language extras remain feature-specific.'
