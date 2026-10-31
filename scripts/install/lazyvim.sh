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
  python3 "$DOTFILES_ROOT/scripts/lib/publish_config.py" "$_dotfiles_stage_dir/nvim" "$config"
else
  echo 'Preserved existing Neovim config and plugins. No sync or replacement performed.'
fi
block_end LazyVim
##### end LazyVim install #####
