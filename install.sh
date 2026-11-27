#!/usr/bin/env bash
# Update this repo, install missing tools, update managed tools, and apply the repo Neovim, Atuin,
# and shell configs. Rerun it to update everything.
# Usage: bash install.sh [--verbose]   show every command's output (or DOTFILES_VERBOSE=1)
#        bash install.sh --version     this checkout's version and the last installs here
# Run as a normal user; system setup may request sudo. Your default shell is unchanged.
set -euo pipefail
DOTFILES_ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
usage() { echo 'Usage: bash install.sh [--verbose] | --version | --help' >&2; exit 2; }
dotfiles_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) DOTFILES_VERBOSE=1; dotfiles_args+=("$1") ;;
    --version) source "$DOTFILES_ROOT/scripts/version.sh"; dotfiles_show_version; exit 0 ;;
    -h|--help) sed -n '2,6p' "$DOTFILES_ROOT/install.sh"; exit 0 ;;
    *) usage ;;
  esac
  shift
done
# Modules share this process (PATH changes, temp cleanup); run this file, not them.
source "$DOTFILES_ROOT/scripts/lib/common.sh"
source "$DOTFILES_ROOT/scripts/platform.sh"
source "$DOTFILES_ROOT/scripts/version.sh"
source "$DOTFILES_ROOT/scripts/pull.sh"
source "$DOTFILES_ROOT/scripts/discover.sh"
source "$DOTFILES_ROOT/scripts/components.sh"
source "$DOTFILES_ROOT/scripts/lib/temp.sh"
source "$DOTFILES_ROOT/scripts/install/prerequisites.sh"
source "$DOTFILES_ROOT/scripts/install/homebrew.sh"
source "$DOTFILES_ROOT/scripts/install/mason-path.sh"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
source "$DOTFILES_ROOT/scripts/update.sh"
install_tools 'Core tools' "${core_tools[@]}"
source "$DOTFILES_ROOT/scripts/install/neovim.sh"
install_tools 'Search tools' "${search_tools[@]}"
install_tools 'Python and Node' "${language_tools[@]}"
source "$DOTFILES_ROOT/scripts/install/rust.sh"
source "$DOTFILES_ROOT/scripts/install/scout.sh"
install_tools 'Formatters and linters' "${format_tools[@]}"
source "$DOTFILES_ROOT/scripts/install/shell.sh"
source "$DOTFILES_ROOT/scripts/install/dot.sh"
source "$DOTFILES_ROOT/scripts/install/keyboard.sh"
source "$DOTFILES_ROOT/scripts/install/lazyvim.sh"

dotfiles_record_install
printf '\nDone in %ss (dotfiles %s).\n' "$SECONDS" "$(dotfiles_version)"
if [[ ${#dotfiles_rc_changes[@]} -gt 0 ]]; then
  changed=$(printf '%s\n' "${dotfiles_rc_changes[@]}" | sort -u | while read -r f; do short_path "$f"; printf ' '; done)
  echo "Added startup lines to ${changed% }. Open a new terminal to load them."
fi
# shellcheck disable=SC2016 # prints the command for the user to run
[[ "$brew_new" != true ]] || printf 'Or load Homebrew in this one: eval "$("%s" shellenv)"\n' "$(command -v brew)"
