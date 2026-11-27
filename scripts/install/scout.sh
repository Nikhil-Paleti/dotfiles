# Install scout, the indexed code search that Neovim's grep and file keys use in indexed repos
# (config/nvim/lua/plugins/scout.lua). One checkout of scout's main branch, in this repo's
# modules/scout (git-ignored, so deleting the dotfiles folder deletes it too), serves both
# halves: each run fast-forwards it,
# cargo builds the binary from it, and Neovim loads the plugin's Lua from the same folder, so
# the two always match. A rerun with no new commits takes a second. A scout binary that this
# step did not install (another package manager, or your own `cargo install --path` build
# elsewhere) stays first on PATH; Neovim still uses the checkout's own build.
# Runs after scripts/install/rust.sh, which provides cargo.
##### scout install #####
block_start scout
scout_repo='https://github.com/Nikhil-Paleti/scout'
scout_dir="$DOTFILES_ROOT/modules/scout"
if [[ -d "$scout_dir/.git" ]]; then
  scout_origin=$(git -C "$scout_dir" remote get-url origin 2>/dev/null || true)
  if [[ "${scout_origin%.git}" != "$scout_repo" ]]; then
    echo "$scout_dir is a git checkout of ${scout_origin:-an unknown repo}, not scout." >&2
    echo 'Move it aside, then rerun bash install.sh.' >&2
    exit 1
  fi
  if ! git -C "$scout_dir" pull --ff-only --quiet; then
    echo "Could not fast-forward $scout_dir (local changes or another branch); building what is checked out." >&2
  fi
elif [[ -e "$scout_dir" ]]; then
  echo "$scout_dir exists but is not a git checkout. Move it aside, then rerun bash install.sh." >&2
  exit 1
else
  mkdir -p "$(dirname "$scout_dir")"
  git clone --quiet "$scout_repo" "$scout_dir"
fi
echo "scout checkout: $(git -C "$scout_dir" log -1 --format='%h %s (%cs)') in $scout_dir"
# shellcheck disable=SC2154 # cargo_home is set by scripts/install/rust.sh
scout_cargo_bin="$cargo_home/bin/scout"
# cargo records where each installed binary came from in .crates.toml.
scout_source=$(grep -E '^"scout [^ ]+ \(' "$cargo_home/.crates.toml" 2>/dev/null || true)
if have scout && [[ "$(command -v scout)" != "$scout_cargo_bin" ]]; then
  scout_other="$(command -v scout), installed outside cargo's bin directory"
elif [[ -x "$scout_cargo_bin" && -n "$scout_source" && "$scout_source" != *"(path+file://$scout_dir/crates/scout)"* ]]; then
  scout_other="$scout_cargo_bin, installed by cargo from another source: $scout_source"
else
  scout_other=''
fi
if [[ -z "$scout_other" ]]; then
  # Builds in the checkout's target folder, so a rerun with no new commits only relinks.
  cargo install --locked --path "$scout_dir/crates/scout"
else
  echo "Keeping the scout on PATH ($scout_other)."
  echo 'To use the main-branch build in the terminal too: cargo uninstall scout (or remove that one), then rerun.'
  cargo build --release --locked --quiet --manifest-path "$scout_dir/Cargo.toml" -p scout
fi
# The plugin runs this build first (lua/scout/util.lua), whatever is on PATH.
[[ -x "$scout_dir/target/release/scout" ]] || { echo "No scout build in $scout_dir/target/release; rerun bash install.sh." >&2; exit 1; }
have scout || { echo 'scout is not on PATH after cargo install; check cargo install --list, then rerun.' >&2; exit 1; }
echo "Neovim uses $("$scout_dir/target/release/scout" version) from $scout_dir; the terminal uses $(command -v scout)."
block_end scout
##### end scout install #####
