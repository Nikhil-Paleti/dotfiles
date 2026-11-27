#!/usr/bin/env bash
# Install missing tools, update managed tools, and apply the repo Neovim, Atuin, and shell configs.
# Usage: bash install.sh [--verbose]   (or DOTFILES_VERBOSE=1) to show every command's output.
# Run as a normal user; system setup may request sudo. Your default shell is unchanged.
set -euo pipefail
DOTFILES_ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
[[ $# -le 1 ]] || { echo 'Only one argument is supported.' >&2; exit 2; }
case "${1:-}" in
  '') ;;
  -v|--verbose) DOTFILES_VERBOSE=1 ;;
  -h|--help) sed -n '2,4p' "$DOTFILES_ROOT/install.sh"; exit 0 ;;
  *) echo 'Usage: bash install.sh [--verbose|--help]' >&2; exit 2 ;;
esac
# Modules share this process (PATH changes, temp cleanup); run this file, not them.
source "$DOTFILES_ROOT/scripts/lib/common.sh"
source "$DOTFILES_ROOT/scripts/platform.sh"
source "$DOTFILES_ROOT/scripts/discover.sh"
source "$DOTFILES_ROOT/scripts/components.sh"
source "$DOTFILES_ROOT/scripts/lib/temp.sh"
source "$DOTFILES_ROOT/scripts/install/prerequisites.sh"
source "$DOTFILES_ROOT/scripts/install/homebrew.sh"
source "$DOTFILES_ROOT/scripts/install/mason-path.sh"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
source "$DOTFILES_ROOT/scripts/update.sh"
install_tools 'Core tools' git jj gh curl bazelisk
source "$DOTFILES_ROOT/scripts/install/neovim.sh"
install_tools 'Search tools' rg fd lazygit fzf
install_tools 'Python and Node' python3 uv node npm
source "$DOTFILES_ROOT/scripts/install/rust.sh"
source "$DOTFILES_ROOT/scripts/install/scout.sh"
install_tools 'Formatters and linters' tree-sitter stylua shfmt shellcheck ruff
source "$DOTFILES_ROOT/scripts/install/shell.sh"
source "$DOTFILES_ROOT/scripts/install/keyboard.sh"
lazy_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
source "$DOTFILES_ROOT/scripts/install/lazyvim.sh"

printf '\nDone in %ss.\n' "$SECONDS"
if [[ ${#dotfiles_rc_changes[@]} -gt 0 ]]; then
  changed=$(printf '%s\n' "${dotfiles_rc_changes[@]}" | sort -u | while read -r f; do short_path "$f"; printf ' '; done)
  echo "Added startup lines to ${changed% }. Open a new terminal to load them."
fi
# shellcheck disable=SC2016 # prints the command for the user to run
[[ "$brew_new" != true ]] || printf 'Or load Homebrew in this one: eval "$("%s" shellenv)"\n' "$(command -v brew)"
[[ -d "$lazy_dir" ]] || echo 'Start nvim once to install its plugins, then run :LazyHealth.'
