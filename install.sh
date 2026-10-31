#!/usr/bin/env bash
# Install the terminal/editor toolchain; no personal dotfiles in this PR.
# Usage: bash install.sh --check | --install
# --check is the default: no writes, downloads, or package-manager operations.
# --install uses Homebrew; Debian/Ubuntu also use apt for bootstrap dependencies.
# Requires network; pre-authorized sudo may be needed. No interactive prompts.
# Run as your normal user; provision Apple command-line tools separately.
# Existing tools/config are retained. No login, chsh, shell-file edits, or upgrades.
# Fresh LazyVim gets upstream starter + plugin sync; existing config is never run.
# Nerd Fonts/terminal settings, conda, OrbStack, and language extras are out of scope.
# Sources: https://www.lazyvim.org/ https://www.lazyvim.org/installation
# https://docs.brew.sh/Installation https://docs.brew.sh/Homebrew-on-Linux
set -euo pipefail
mode=check
case "${1:---check}" in
  --check) ;;
  --install) mode=install ;;
  -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
  *) echo 'Usage: bash install.sh [--check|--install]' >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo 'Only one argument is supported.' >&2; exit 2; }
[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo 'Run as your normal user, not root.' >&2; exit 1; }
os=$(uname -s)
case "$os" in
  Darwin) ;;
  Linux)
    [[ -r /etc/os-release ]] || { echo 'Cannot identify Linux distribution.' >&2; exit 1; }
    . /etc/os-release
    case "${ID:-} ${ID_LIKE:-}" in
      *ubuntu*|*debian*) ;;
      *) echo 'Supported: macOS and Debian/Ubuntu Linux (including WSL2).' >&2; exit 1 ;;
    esac ;;
  *) echo 'Supported: macOS and Debian/Ubuntu Linux/WSL2; not native Windows.' >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64|x86_64) ;;
  *) echo 'Supported architectures: ARM64 and x86_64.' >&2; exit 1 ;;
esac
# Discover standard installations without writing shell startup files.
if ! command -v brew >/dev/null 2>&1; then
for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
  if [[ -x "$prefix/bin/brew" ]]; then
    export PATH="$prefix/bin:$prefix/sbin:$PATH"
    break
  fi
done
fi
# Reuse tools already installed by Mason instead of installing duplicate copies.
mason_bin="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin"
[[ ! -d "$mason_bin" ]] || export PATH="$PATH:$mason_bin"
have() { command -v "$1" >/dev/null 2>&1; }
# Compare numeric versions without requiring Python/Node to be installed first.
at_least() {
  awk -v actual="$1" -v required="$2" 'BEGIN {
    split(actual,a,"."); split(required,r,".");
    for(i=1;i<=3;i++){if(a[i]+0>r[i]+0)exit 0;if(a[i]+0<r[i]+0)exit 1}exit 0
  }'
}
version_ok() {
  case "$1" in
    nvim) at_least "$(nvim --version | awk 'NR==1 {sub(/^v/,"",$2); print $2}')" 0.11.2 ;;
    git) at_least "$(git --version | awk '{print $3}')" 2.19.0 ;;
    *) return 0 ;;
  esac
}
# command:Homebrew formula. Skip any usable command from another manager too.
requirements=(git:git curl:curl tmux:tmux nvim:neovim rg:ripgrep fd:fd
  lazygit:lazygit fzf:fzf tree-sitter:tree-sitter python3:python node:node
  npm:node zsh:zsh stylua:stylua shfmt:shfmt shellcheck:shellcheck)
missing=0
printf '%-24s %s\n' COMPONENT STATUS
for item in "${requirements[@]}"; do
  cmd=${item%%:*}
  if have "$cmd"; then
    if version_ok "$cmd"; then
      printf '%-24s present\n' "$cmd"
    else
      printf '%-24s incompatible-version\n' "$cmd"; missing=1
    fi
  else
    printf '%-24s missing\n' "$cmd"; missing=1
  fi
done
for cmd in cc make; do
  if have "$cmd"; then printf '%-24s present\n' "$cmd"; else printf '%-24s missing\n' "$cmd"; missing=1; fi
done
config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
if [[ -e "$config" || -L "$config" ]]; then
  printf '%-24s existing-config-preserved\n' LazyVim
else
  printf '%-24s missing-starter\n' LazyVim; missing=1
fi
for formula in zsh-autosuggestions zsh-completions zsh-syntax-highlighting; do
  if have brew && [[ -d "$(brew --prefix)/share/$formula" ]]; then
    printf '%-24s present\n' "$formula"
  else
    printf '%-24s missing\n' "$formula"; missing=1
  fi
done
if [[ "$mode" == check ]]; then
  echo 'Check only. No changes made. Run with --install to provision missing components.'
  echo 'Existing Neovim config is not inspected/executed; plugin health is not verified.'
  exit "$missing"
fi
# Do not let child installers read terminal input. Privilege failures stop the run.
exec </dev/null
# An installed but too-old editor/Git may belong to another manager. Do not
# silently upgrade or replace it; let the owner choose how to resolve it.
for cmd in git nvim; do
  if have "$cmd" && ! version_ok "$cmd"; then
    echo "$cmd is too old; update it using its current package manager, then retry." >&2
    exit 1
  fi
done
##### Build prerequisites install #####
printf '\n##### Build prerequisites install #####\n'
if [[ "$os" == Darwin ]]; then
  if ! xcode-select -p >/dev/null 2>&1 || ! have cc || ! have make; then
    echo 'Installing Apple command-line tools requires its GUI. Run xcode-select --install, finish, then rerun.' >&2
    exit 1
  fi
else
  deps=()
  for pair in cc:build-essential make:build-essential g++:build-essential curl:curl file:file git:git ps:procps; do
    have "${pair%%:*}" || deps+=("${pair#*:}")
  done
  if [[ ${#deps[@]} -gt 0 ]]; then
    have sudo || { echo 'sudo is required for missing Linux bootstrap packages.' >&2; exit 1; }
    sudo -n apt-get update
    sudo -n apt-get install -y "${deps[@]}" ca-certificates
  fi
fi
printf '##### end Build prerequisites install #####\n'
##### end Build prerequisites install #####
# Never consume inherited temporary-path variables. Cleanup is limited to
# directories allocated here and bearing this process's ownership marker.
_dotfiles_download_dir=''
_dotfiles_stage_dir=''
readonly _dotfiles_cleanup_owner="$$:$RANDOM:$RANDOM"
_dotfiles_remove_owned() {
  local owned_dir="$1"
  if [[ -n "$owned_dir" && -d "$owned_dir" && ! -L "$owned_dir" &&
        -f "$owned_dir/.dotfiles-installer-owner" && ! -L "$owned_dir/.dotfiles-installer-owner" ]] &&
     [[ "$(cat "$owned_dir/.dotfiles-installer-owner")" == "$_dotfiles_cleanup_owner" ]]; then
    rm -rf -- "$owned_dir"
  fi
  return 0
}
_dotfiles_cleanup() {
  local saved_status=$?
  trap - EXIT
  _dotfiles_remove_owned "$_dotfiles_download_dir"
  _dotfiles_remove_owned "$_dotfiles_stage_dir"
  exit "$saved_status"
}
trap _dotfiles_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
_dotfiles_download_dir=$(mktemp -d)
readonly _dotfiles_download_dir
printf '%s\n' "$_dotfiles_cleanup_owner" > "$_dotfiles_download_dir/.dotfiles-installer-owner"
##### Homebrew install #####
printf '\n##### Homebrew install #####\n'
if ! have brew; then
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$_dotfiles_download_dir/homebrew.sh"
  NONINTERACTIVE=1 /bin/bash "$_dotfiles_download_dir/homebrew.sh"
  for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [[ -x "$prefix/bin/brew" ]]; then export PATH="$prefix/bin:$prefix/sbin:$PATH"; break; fi
  done
fi
have brew || { echo 'Homebrew unavailable after installation.' >&2; exit 1; }
printf '##### end Homebrew install #####\n'
##### end Homebrew install #####
# Homebrew can install dependencies of these packages. It does not configure zsh.
export NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
block_start() { printf '\n##### %s install #####\n' "$1"; }
block_end() { printf '##### end %s install #####\n' "$1"; }
install_tool() {
  local label="$1" command_name="$2" formula_name="$3"
  block_start "$label"
  if have "$command_name"; then
    echo 'Already present; skipped.'
  else
    brew install "$formula_name"
    have "$command_name" || { echo "$command_name is not on PATH after install; resolve package-manager conflicts and retry." >&2; exit 1; }
  fi
  block_end "$label"
}

##### Git install #####
install_tool "Git" git git
##### end Git install #####

##### curl install #####
install_tool "curl" curl curl
##### end curl install #####

##### tmux install #####
install_tool "tmux" tmux tmux
##### end tmux install #####

##### Neovim install #####
install_tool "Neovim" nvim neovim
##### end Neovim install #####

##### ripgrep install #####
install_tool "ripgrep" rg ripgrep
##### end ripgrep install #####

##### fd install #####
install_tool "fd" fd fd
##### end fd install #####

##### lazygit install #####
install_tool "lazygit" lazygit lazygit
##### end lazygit install #####

##### fzf install #####
install_tool "fzf" fzf fzf
##### end fzf install #####

##### Tree-sitter CLI install #####
install_tool "Tree-sitter CLI" tree-sitter tree-sitter
##### end Tree-sitter CLI install #####

##### Python 3 install #####
install_tool "Python 3" python3 python
##### end Python 3 install #####

##### Node.js install #####
install_tool "Node.js" node node
##### end Node.js install #####

##### npm install #####
install_tool "npm" npm node
##### end npm install #####

##### zsh install #####
install_tool "zsh" zsh zsh
##### end zsh install #####

##### StyLua install #####
install_tool "StyLua" stylua stylua
##### end StyLua install #####

##### shfmt install #####
install_tool "shfmt" shfmt shfmt
##### end shfmt install #####

##### ShellCheck install #####
install_tool "ShellCheck" shellcheck shellcheck
##### end ShellCheck install #####

##### zsh-autosuggestions install #####
block_start zsh-autosuggestions
if [[ -d "$(brew --prefix)/share/zsh-autosuggestions" ]]; then
  echo 'Already present; skipped.'
else
  brew install zsh-autosuggestions
fi
block_end zsh-autosuggestions
##### end zsh-autosuggestions install #####

##### zsh-completions install #####
block_start zsh-completions
if [[ -d "$(brew --prefix)/share/zsh-completions" ]]; then
  echo 'Already present; skipped.'
else
  brew install zsh-completions
fi
block_end zsh-completions
##### end zsh-completions install #####

##### zsh-syntax-highlighting install #####
block_start zsh-syntax-highlighting
if [[ -d "$(brew --prefix)/share/zsh-syntax-highlighting" ]]; then
  echo 'Already present; skipped.'
else
  brew install zsh-syntax-highlighting
fi
block_end zsh-syntax-highlighting
##### end zsh-syntax-highlighting install #####
##### LazyVim install #####
block_start LazyVim
if [[ ! -e "$config" && ! -L "$config" ]]; then
  mkdir -p "$(dirname "$config")"
  _dotfiles_stage_dir=$(mktemp -d "${config}.install.XXXXXX")
  readonly _dotfiles_stage_dir
  printf '%s\n' "$_dotfiles_cleanup_owner" > "$_dotfiles_stage_dir/.dotfiles-installer-owner"
  git clone --depth 1 https://github.com/LazyVim/starter "$_dotfiles_stage_dir/nvim"
  # Sync against temporary config, using the normal nvim data/cache directories.
  # Failures leave the destination absent; retry reuses downloaded plugin data.
  XDG_CONFIG_HOME="$_dotfiles_stage_dir" NVIM_APPNAME=nvim nvim --headless '+Lazy! sync' +qa
  # Atomically publish a completed config, refusing even concurrent collisions.
  # renameat2(RENAME_NOREPLACE) on Linux; renamex_np(RENAME_EXCL) on macOS.
  python3 - "$_dotfiles_stage_dir/nvim" "$config" <<'PYTHON'
import ctypes
import os
import sys
libc = ctypes.CDLL(None, use_errno=True)
source, destination = map(os.fsencode, sys.argv[1:])
if sys.platform == "darwin":
    rename = libc.renamex_np
    rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    result = rename(source, destination, 4)
else:
    rename = libc.renameat2
    rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    result = rename(-100, source, -100, destination, 1)
if result != 0:
    error = ctypes.get_errno()
    raise OSError(error, "Config publication refused: " + os.strerror(error))
PYTHON
else
  echo 'Preserved existing Neovim config and plugins. No sync or replacement performed.'
fi
block_end LazyVim
##### end LazyVim install #####
printf '\nProvisioning finished. Existing configurations were preserved.\n'
printf 'Homebrew PATH for future shells: eval "$(%s shellenv)"\n' "$(command -v brew)"
echo 'Zsh plugins are installed, not enabled; shell dotfiles will be a separate PR.'
echo 'Choose a Nerd Font in your terminal for icons; fonts/terminal settings are not changed.'
echo 'Start nvim and run :LazyHealth; language extras and Mason tools remain feature-specific.'
echo 'No conda, OrbStack, auth, chsh, or changes to existing dotfiles were made.'
