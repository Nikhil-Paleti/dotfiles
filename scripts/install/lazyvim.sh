# Copy the repo's Neovim config into place, keeping a unique backup of the old one.
# Run one installer at a time; backups are never removed automatically.
block_start LazyVim
source_config="$DOTFILES_ROOT/config/nvim"
config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
[[ -d "$source_config" && ! -L "$source_config" && -f "$source_config/init.lua" ]] || {
  echo "Missing repo Neovim config: $source_config" >&2; exit 1;
}
mkdir -p "$(dirname "$config")"
_dotfiles_stage_dir=$(mktemp -d "${config}.install.XXXXXX")
readonly _dotfiles_stage_dir
printf '%s\n' "$_dotfiles_cleanup_owner" > "$_dotfiles_stage_dir/.dotfiles-installer-owner"
cp -Rp "$source_config" "$_dotfiles_stage_dir/nvim"
backup=''
if [[ -e "$config" || -L "$config" ]]; then
  backup=$(mktemp -d "${config}.backup.XXXXXX")
  printf 'Backup location: %s/nvim\n' "$backup"
  mv "$config" "$backup/nvim"
fi
if [[ -e "$config" || -L "$config" ]] || ! mv "$_dotfiles_stage_dir/nvim" "$config"; then
  echo 'Could not install Neovim config.' >&2
  if [[ -n "$backup" ]]; then
    if [[ ! -e "$config" && ! -L "$config" ]] && mv "$backup/nvim" "$config"; then
      echo 'Previous config restored.' >&2
    else
      printf 'Previous config is at %s/nvim; restore it manually.\n' "$backup" >&2
    fi
  fi
  exit 1
fi
block_end LazyVim
