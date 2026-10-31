#!/usr/bin/env bash
# Install the terminal/editor toolchain; no personal dotfiles in this PR.
# Usage: bash install.sh --check | --install
# --check is the default: no writes, downloads, or package-manager operations.
# --install uses Homebrew; Debian/Ubuntu also use apt for bootstrap dependencies.
# Requires network; sudo may be requested by apt/Homebrew. Run as your normal user.
# Existing tools/config are retained. No login, chsh, shell-file edits, or upgrades.
# Fresh LazyVim gets upstream starter + plugin sync; existing config is never run.
# Nerd Fonts/terminal settings, conda, OrbStack, and language extras are out of scope.
# Sources: https://www.lazyvim.org/ https://www.lazyvim.org/installation
# https://docs.brew.sh/Installation https://docs.brew.sh/Homebrew-on-Linux
# https://github.com/openai/codex
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
for item in "${requirements[@]}" codex:codex; do
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
# An installed but too-old editor/Git may belong to another manager. Do not
# silently upgrade or replace it; let the owner choose how to resolve it.
for cmd in git nvim; do
  if have "$cmd" && ! version_ok "$cmd"; then
    echo "$cmd is too old; update it using its current package manager, then retry." >&2
    exit 1
  fi
done
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
    sudo apt-get update
    sudo apt-get install -y "${deps[@]}" ca-certificates
  fi
fi
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
if ! have brew; then
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$scratch/homebrew.sh"
  /bin/bash "$scratch/homebrew.sh"
  for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [[ -x "$prefix/bin/brew" ]]; then export PATH="$prefix/bin:$prefix/sbin:$PATH"; break; fi
  done
fi
have brew || { echo 'Homebrew unavailable after installation.' >&2; exit 1; }
# Homebrew can install dependencies of these packages. It does not configure zsh.
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
for item in "${requirements[@]}"; do
  cmd=${item%%:*}; formula=${item#*:}
  if ! have "$cmd"; then
    brew install "$formula"
    have "$cmd" || { echo "$cmd is not on PATH after install; resolve package-manager conflicts and retry." >&2; exit 1; }
  fi
done
for formula in zsh-autosuggestions zsh-completions zsh-syntax-highlighting; do
  [[ -d "$(brew --prefix)/share/$formula" ]] || brew install "$formula"
done
if ! have codex; then
  # Official standalone installer avoids npm global permission changes.
  curl -fsSL https://chatgpt.com/codex/install.sh -o "$scratch/codex.sh"
  sh "$scratch/codex.sh"
  export PATH="$HOME/.local/bin:$PATH"
  have codex || { echo 'Codex installed but not on PATH; follow installer instructions.' >&2; exit 1; }
fi
if [[ ! -e "$config" && ! -L "$config" ]]; then
  # Clone in a temporary directory first. mkdir refuses a concurrent collision.
  git clone --depth 1 https://github.com/LazyVim/starter "$scratch/nvim"
  mkdir -p "$(dirname "$config")"
  mkdir "$config"
  cp -R "$scratch/nvim/." "$config/"
  # Bootstrap the fresh starter only; existing user config is never executed.
  NVIM_APPNAME=nvim nvim --headless '+Lazy! sync' +qa
else
  echo 'Preserved existing Neovim config and plugins. No sync or replacement performed.'
fi
printf '\nProvisioning finished. Existing configurations were preserved.\n'
printf 'Homebrew PATH for future shells: eval "$(%s shellenv)"\n' "$(command -v brew)"
echo 'Codex may also require $HOME/.local/bin on PATH. Sign in manually using codex.'
echo 'Zsh plugins are installed, not enabled; shell dotfiles will be a separate PR.'
echo 'Choose a Nerd Font in your terminal for icons; fonts/terminal settings are not changed.'
echo 'Start nvim and run :LazyHealth; language extras and Mason tools remain feature-specific.'
echo 'No conda, OrbStack, auth, chsh, or changes to existing dotfiles were made.'
