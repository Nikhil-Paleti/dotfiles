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
# Throwaway repos and index cache. The cache path stays short: the indexer's socket lives in
# it, and socket paths are capped near 104 characters (macOS's mktemp folders are long).
scout_tmp=$(mktemp -d)
export SCOUT_CACHE_DIR
SCOUT_CACHE_DIR=$(mktemp -d /tmp/scout.XXXXXX)
new_repo() {
  mkdir -p "$1/src"
  printf '%s\n' 'int hello_world(void) { return 1; }' 'int main() { return hello_world(); }' \
    > "$1/src/a.c"
  git init -q "$1"
}
# The CLI indexes a repo and finds both hits and the definition.
new_repo "$scout_tmp/repo"
scout build --quiet --root "$scout_tmp/repo"
hits=$(scout search --root "$scout_tmp/repo" -F hello_world)
printf '%s\n' "$hits"
[[ $(grep -c '^src/a.c:' <<<"$hits") -eq 2 ]] || { echo 'scout did not find both hits.' >&2; exit 1; }
scout search --root "$scout_tmp/repo" 'sym:hello_world' | grep -q '^src/a.c:1:.*\[function\]' ||
  { echo 'scout did not find the definition.' >&2; exit 1; }
# The Neovim plugin loads from install.sh's scout checkout and uses the build in it.
scout_dir="$repo/modules/scout"
# The installed Neovim config knows where this repo is (written by scripts/install/lazyvim.sh).
grep -Fq "$repo" "$config_home/nvim/lua/dotfiles_root.lua" ||
  { echo 'The installed Neovim config does not point at this repo.' >&2; exit 1; }
git -C "$scout_dir" log -1 --format='scout checkout: %h %s'
# Opening Neovim in a repo with no index indexes it, with the same opts as the plugin spec. The
# check runs on VimEnter, as lazy.nvim's VeryLazy does: setup comes after startup.
new_repo "$scout_tmp/fresh"
cat > "$scout_tmp/check.lua" <<'LUA'
local plugin, repo = vim.env.SCOUT_PLUGIN, vim.env.SCOUT_REPO
vim.opt.rtp:prepend(plugin)
vim.cmd("runtime plugin/scout.lua")
vim.cmd("cd " .. vim.fn.fnameescape(repo))
require("scout").setup({ route_lazyvim_keys = false })
local util = require("scout.util")
local bin = util.bin()
if bin ~= plugin .. "/target/release/scout" then
  io.stderr:write("scout plugin: expected the checkout's build, got " .. tostring(bin) .. "\n")
  vim.cmd("cq!")
end
local root = util.git_root()
local function indexed()
  local ok, st = pcall(vim.json.decode, vim.fn.system({ bin, "status", "--json", "--root", root }))
  return ok and type(st) == "table" and st.indexed == true
end
local done = vim.wait(30000, indexed, 200)
io.stdout:write(("scout plugin: binary %s, indexed on open: %s\n"):format(bin, tostring(done)))
if done then
  vim.cmd("Scout hello_world")
  done = vim.wait(10000, function() return #vim.fn.getqflist() == 2 end, 50)
  io.stdout:write(("scout plugin: %d quickfix hits\n"):format(#vim.fn.getqflist()))
end
vim.fn.system({ bin, "stop", "--root", root })
vim.cmd(done and "qa!" or "cq!")
LUA
SCOUT_PLUGIN="$scout_dir" SCOUT_REPO="$scout_tmp/fresh" \
  nvim --headless -u NONE -i NONE -c "au VimEnter * ++once ++nested luafile $scout_tmp/check.lua" </dev/null ||
  { echo 'The scout Neovim plugin did not index on open or could not search.' >&2; exit 1; }
rm -rf "$scout_tmp" "$SCOUT_CACHE_DIR"
unset SCOUT_CACHE_DIR

echo '--- Status bar branch'
# lua/repo_head.lua (the status bar's branch) in a git repo on a branch, a jj repo with a
# bookmark, and a folder outside any repo. It loads alone, without the plugins.
head_tmp=$(mktemp -d)
mkdir -p "$head_tmp/git" "$head_tmp/jj" "$head_tmp/plain"
git init -q -b trunk "$head_tmp/git"
git -C "$head_tmp/git" -c user.name=ci -c user.email=ci@example.invalid commit -q --allow-empty -m init
(cd "$head_tmp/jj" && jj git init --colocate >/dev/null 2>&1 && jj bookmark create topic -r @ >/dev/null 2>&1)
cat > "$head_tmp/check.lua" <<'LUA'
vim.opt.rtp:prepend(vim.env.NVIM_CONFIG)
local head = require("repo_head")
local function text_in(dir, want_empty)
  vim.cmd("cd " .. vim.fn.fnameescape(dir))
  vim.wait(5000, function() return want_empty or head.get() ~= "" end, 50)
  return head.get()
end
local commit = vim.trim(vim.fn.system({ "git", "-C", vim.env.HEAD_TMP .. "/git", "rev-parse", "--short=6", "HEAD" }))
local change = vim.trim(vim.fn.system({ "jj", "-R", vim.env.HEAD_TMP .. "/jj", "log", "--no-graph", "--ignore-working-copy", "-r", "@", "-T", "change_id.shortest(8)" }))
local cases = {
  { "git", head.git_icon .. "trunk " .. commit },
  { "jj", head.jj_icon .. "topic " .. change },
  { "plain", "" },
}
local ok = true
for _, case in ipairs(cases) do
  local got = text_in(vim.env.HEAD_TMP .. "/" .. case[1], case[2] == "")
  io.stdout:write(("status bar branch, %s: [%s]\n"):format(case[1], got))
  ok = ok and got == case[2]
end
vim.cmd(ok and "qa!" or "cq!")
LUA
HEAD_TMP="$head_tmp" NVIM_CONFIG="$config_home/nvim" \
  nvim --headless -u NONE -i NONE -c "luafile $head_tmp/check.lua" </dev/null ||
  { echo 'The status bar branch is wrong in a git repo, a jj repo or outside a repo.' >&2; exit 1; }
rm -rf "$head_tmp"

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
