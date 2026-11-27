# scout, the indexed code search behind Neovim's grep and file keys (lua/plugins/scout.lua).
# One checkout of scout's main in modules/scout (git-ignored) serves both halves: each run
# fast-forwards it, cargo builds the binary from it, and Neovim loads the plugin from it.
# A scout on PATH that this step didn't install stays there; Neovim still uses the checkout's.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
step scout
scout_repo='https://github.com/Nikhil-Paleti/scout'
scout_dir="$DOTFILES_ROOT/modules/scout"
if [[ -d "$scout_dir/.git" ]]; then
  scout_origin=$(git -C "$scout_dir" remote get-url origin 2>/dev/null || true)
  [[ "${scout_origin%.git}" == "$scout_repo" ]] ||
    die "$scout_dir is a git checkout of ${scout_origin:-an unknown repo}, not scout. Move it aside, then rerun."
  run git -C "$scout_dir" pull --ff-only --quiet ||
    warn "Could not fast-forward $scout_dir (local changes or another branch); building what is checked out."
elif [[ -e "$scout_dir" ]]; then
  die "$scout_dir exists but is not a git checkout. Move it aside, then rerun bash install.sh."
else
  mkdir -p "$(dirname "$scout_dir")"
  run git clone --quiet "$scout_repo" "$scout_dir"
fi
scout_cargo_bin="$cargo_home/bin/scout"
# cargo records where each installed binary came from in .crates.toml.
scout_source=$(grep -E '^"scout [^ ]+ \(' "$cargo_home/.crates.toml" 2>/dev/null || true)
scout_other=''
if have scout && [[ "$(command -v scout)" != "$scout_cargo_bin" ]]; then
  scout_other="$(command -v scout)"
elif [[ -x "$scout_cargo_bin" && -n "$scout_source" && "$scout_source" != *"(path+file://$scout_dir/crates/scout)"* ]]; then
  scout_other="$scout_cargo_bin, from $scout_source"
fi
if [[ -z "$scout_other" ]]; then
  # Builds in the checkout's target folder, so a rerun with no new commits only relinks.
  run cargo install --locked --path "$scout_dir/crates/scout"
else
  detail 'To use the main-branch build in the terminal too: cargo uninstall scout (or remove that one), then rerun.'
  run cargo build --release --locked --quiet --manifest-path "$scout_dir/Cargo.toml" -p scout
fi
# The plugin runs this build first (lua/scout/util.lua), whatever is on PATH.
[[ -x "$scout_dir/target/release/scout" ]] || die "No scout build in $scout_dir/target/release; rerun bash install.sh."
have scout || die 'scout is not on PATH after cargo install; check cargo install --list, then rerun.'
ok "$(git -C "$scout_dir" log -1 --format='%h, %cs')${scout_other:+; terminal keeps $scout_other}"
