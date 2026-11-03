# Stage the complete repo config before replacing the installed copy.
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
rm -rf -- "$config"
mv "$_dotfiles_stage_dir/nvim" "$config"
block_end LazyVim
