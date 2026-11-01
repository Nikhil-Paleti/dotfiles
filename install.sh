#!/usr/bin/env bash
# Usage: bash install.sh [--check|--install|--update]
# --check reports availability; --install adds missing tools; --update upgrades managed tools.
# Run as a normal user on macOS or Debian/Ubuntu Linux/WSL2 (ARM64/x86_64).
# Existing tools/config stay intact. No authentication or shell-profile edits.
set -euo pipefail
DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
[[ $# -le 1 ]] || { echo 'Only one argument is supported.' >&2; exit 2; }
mode=check
case "${1:---check}" in
  --check) ;;
  --install) mode=install ;;
  --update) mode=update ;;
  -h|--help) sed -n '2,5p' "$DOTFILES_ROOT/install.sh"; exit 0 ;;
  *) echo 'Usage: bash install.sh [--check|--install|--update]' >&2; exit 2 ;;
esac
# Modules are sourced in one process so PATH discovery and owned-temp cleanup
# remain available across steps. Invoke this entry point, not modules directly.
source "$DOTFILES_ROOT/scripts/lib/common.sh"
source "$DOTFILES_ROOT/scripts/platform.sh"
source "$DOTFILES_ROOT/scripts/discover.sh"
source "$DOTFILES_ROOT/scripts/check.sh"
# Noninteractive child processes; update does not run the install modules.
exec </dev/null
if [[ "$mode" == update ]]; then
  source "$DOTFILES_ROOT/scripts/update.sh"
  exit 0
fi
source "$DOTFILES_ROOT/scripts/install/prerequisites.sh"
source "$DOTFILES_ROOT/scripts/lib/temp.sh"
source "$DOTFILES_ROOT/scripts/install/homebrew.sh"
export NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
source "$DOTFILES_ROOT/scripts/install/core.sh"
source "$DOTFILES_ROOT/scripts/install/tmux.sh"
source "$DOTFILES_ROOT/scripts/install/neovim.sh"
source "$DOTFILES_ROOT/scripts/install/search.sh"
source "$DOTFILES_ROOT/scripts/install/runtimes.sh"
source "$DOTFILES_ROOT/scripts/install/formatters.sh"
source "$DOTFILES_ROOT/scripts/install/shell.sh"
source "$DOTFILES_ROOT/scripts/install/lazyvim.sh"
printf '\nProvisioning finished. Existing configurations were preserved.\n'
printf 'Homebrew PATH for future shells: eval "$(%s shellenv)"\n' "$(command -v brew)"
echo 'Zsh plugins are installed, not enabled. Choose a Nerd Font for terminal icons.'
echo 'Start nvim and run :LazyHealth. Language extras remain feature-specific.'
echo 'No Conda, OrbStack, authentication, default-shell or existing-dotfile changes.'
