#!/usr/bin/env bash
# CI smoke checks after install.sh: the key tools run, the repo configs landed, scout searches
# from the shell and through its Neovim plugin, and a new interactive shell (bash or zsh, from
# SHELL) finds the tools on PATH.
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
zoxide --version
scout version

echo '--- Configs'
cmp "$repo/config/nvim/init.lua" "$config_home/nvim/init.lua"
cmp "$repo/config/atuin/config.toml" "$atuin_config"
cmp "$repo/config/starship/starship.toml" "${STARSHIP_CONFIG:-$config_home/starship.toml}"
# CI has no sync server or credentials; the repo config must keep sync off.
grep -Eq '^auto_sync[[:space:]]*=[[:space:]]*false' "$atuin_config"
echo 'Neovim, Atuin and Starship configs match the repo; Atuin sync is off.'

echo '--- scout'
# A throwaway repo and index cache: scout indexes it and finds a definition and a call.
scout_tmp=$(mktemp -d)
export SCOUT_CACHE_DIR="$scout_tmp/cache"
mkdir -p "$scout_tmp/repo/src"
printf '%s\n' 'int hello_world(void) { return 1; }' 'int main() { return hello_world(); }' \
  > "$scout_tmp/repo/src/a.c"
git init -q "$scout_tmp/repo"
scout build --quiet --root "$scout_tmp/repo"
hits=$(scout search --root "$scout_tmp/repo" -F hello_world)
printf '%s\n' "$hits"
[[ $(grep -c '^src/a.c:' <<<"$hits") -eq 2 ]] || { echo 'scout did not find both hits.' >&2; exit 1; }
scout search --root "$scout_tmp/repo" 'sym:hello_world' | grep -q '^src/a.c:1:.*\[function\]' ||
  { echo 'scout did not find the definition.' >&2; exit 1; }
# The Neovim plugin, at the commit lazy-lock.json pins, finds the installed binary and fills
# the quickfix list. Plugins are not installed in CI, so it is fetched on its own here.
scout_rev=$(sed -n 's/^ *"scout": {.*"commit": "\([0-9a-f]\{40\}\)".*/\1/p' "$repo/config/nvim/lazy-lock.json")
git init -q "$scout_tmp/plugin"
git -C "$scout_tmp/plugin" fetch -q --depth 1 https://github.com/Nikhil-Paleti/scout "$scout_rev"
git -C "$scout_tmp/plugin" checkout -q FETCH_HEAD
cat > "$scout_tmp/check.lua" <<'LUA'
local plugin, repo = vim.env.SCOUT_PLUGIN, vim.env.SCOUT_REPO
vim.opt.rtp:prepend(plugin)
vim.cmd("runtime plugin/scout.lua")
require("scout").setup({ route_lazyvim_keys = false })
local bin = require("scout.util").bin()
if not bin then
  io.stderr:write("scout plugin: binary not found\n")
  vim.cmd("cq!")
end
vim.cmd("cd " .. vim.fn.fnameescape(repo))
vim.cmd("Scout hello_world")
local ok = vim.wait(10000, function() return #vim.fn.getqflist() == 2 end, 50)
io.stdout:write(("scout plugin: binary %s, %d quickfix hits\n"):format(bin, #vim.fn.getqflist()))
vim.cmd(ok and "qa!" or "cq!")
LUA
SCOUT_PLUGIN="$scout_tmp/plugin" SCOUT_REPO="$scout_tmp/repo" \
  nvim --headless -u NONE -i NONE -c "luafile $scout_tmp/check.lua" </dev/null ||
  { echo 'The scout Neovim plugin could not search with the installed binary.' >&2; exit 1; }
rm -rf "$scout_tmp"
unset SCOUT_CACHE_DIR

echo "--- New ${SHELL##*/} shell"
# stdin is not a terminal here, so line editors such as ble.sh may print warnings;
# only the PATH lookups below decide the result.
# shellcheck disable=SC2016 # $tool expands in the new shell
found=$("$SHELL" -ic 'for tool in nvim atuin starship zoxide scout; do command -v "$tool"; done
  type z zi >/dev/null 2>&1 && echo zoxide-commands' </dev/null 2>/dev/null || true)
printf '%s\n' "$found"
for tool in nvim atuin starship zoxide scout; do
  grep -q "/$tool\$" <<<"$found" || { echo "$tool is not on PATH in a new ${SHELL##*/} shell." >&2; exit 1; }
done
# zoxide's init line ran: z and zi exist. Plain cd is left as the builtin.
grep -qx zoxide-commands <<<"$found" || { echo "z and zi are not defined in a new ${SHELL##*/} shell." >&2; exit 1; }
echo 'Smoke checks passed.'
