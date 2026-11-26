#!/usr/bin/env bash
# CI smoke checks after install.sh: the key tools run, the repo configs landed,
# and a new interactive shell (bash or zsh, from SHELL) finds the tools on PATH.
set -euo pipefail
repo="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
atuin_config="${ATUIN_CONFIG_DIR:-$HOME/.atuin}/config.toml"

# Each CI step is a fresh shell, so load Homebrew the way install.sh finds it.
for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
  if [[ -x "$prefix/bin/brew" ]]; then eval "$("$prefix/bin/brew" shellenv)"; break; fi
done
command -v brew >/dev/null || { echo 'brew not found after install.' >&2; exit 1; }

echo '--- Tools'
nvim --version | head -n 1
atuin --version
starship --version | head -n 1

echo '--- Configs'
cmp "$repo/config/nvim/init.lua" "$config_home/nvim/init.lua"
cmp "$repo/config/atuin/config.toml" "$atuin_config"
cmp "$repo/config/starship/starship.toml" "${STARSHIP_CONFIG:-$config_home/starship.toml}"
# CI has no sync server or credentials; the repo config must keep sync off.
grep -Eq '^auto_sync[[:space:]]*=[[:space:]]*false' "$atuin_config"
echo 'Neovim, Atuin and Starship configs match the repo; Atuin sync is off.'

echo "--- New ${SHELL##*/} shell"
# stdin is not a terminal here, so line editors such as ble.sh may print warnings;
# only the PATH lookups below decide the result.
# shellcheck disable=SC2016 # $tool expands in the new shell
found=$("$SHELL" -ic 'for tool in nvim atuin starship; do command -v "$tool"; done' </dev/null 2>/dev/null || true)
printf '%s\n' "$found"
for tool in nvim atuin starship; do
  grep -q "/$tool\$" <<<"$found" || { echo "$tool is not on PATH in a new ${SHELL##*/} shell." >&2; exit 1; }
done
echo 'Smoke checks passed.'
