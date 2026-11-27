# Install scout, the indexed code search that Neovim's grep keys use in indexed repos
# (config/nvim/lua/plugins/scout.lua). cargo builds it from source at the plugin commit that
# config/nvim/lazy-lock.json pins, so the binary always matches the plugin's Lua. A rerun at
# the same commit skips the build; a newer pinned commit rebuilds it. A scout that this step
# did not install (another package manager, or your own `cargo install --path` build) is
# reused, not replaced. Runs after scripts/install/rust.sh, which provides cargo.
##### scout install #####
block_start scout
scout_repo='https://github.com/Nikhil-Paleti/scout'
scout_lock="$DOTFILES_ROOT/config/nvim/lazy-lock.json"
scout_rev=$(sed -n 's/^ *"scout": {.*"commit": "\([0-9a-f]\{40\}\)".*/\1/p' "$scout_lock")
[[ -n "$scout_rev" ]] || { echo "No scout commit found in $scout_lock." >&2; exit 1; }
# shellcheck disable=SC2154 # cargo_home is set by scripts/install/rust.sh
scout_cargo_bin="$cargo_home/bin/scout"
# cargo records where each installed binary came from in .crates.toml.
scout_source=$(grep -E '^"scout [^ ]+ \(' "$cargo_home/.crates.toml" 2>/dev/null || true)
if have scout && [[ "$(command -v scout)" != "$scout_cargo_bin" ]]; then
  echo "scout is installed outside cargo's bin directory ($(command -v scout)); reused, not upgraded."
elif [[ -x "$scout_cargo_bin" && -n "$scout_source" && "$scout_source" != *"(git+$scout_repo?"* ]]; then
  echo "scout was installed by cargo from another source; reused, not upgraded:"
  echo "  $scout_source"
  echo 'To switch to the pinned build: cargo uninstall scout, then rerun bash install.sh.'
else
  echo "Installing scout at the pinned commit ${scout_rev:0:12} with cargo (skipped if already there)."
  cargo install --locked --git "$scout_repo" --rev "$scout_rev" scout
fi
have scout || { echo 'scout is not on PATH after cargo install; check cargo install --list, then rerun.' >&2; exit 1; }
echo "Using $(scout version) at $(command -v scout)."
block_end scout
##### end scout install #####
