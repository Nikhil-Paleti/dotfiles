# Apply the repo tmux config without following an existing config symlink.
tmux_source="$DOTFILES_ROOT/config/tmux/tmux.conf"
tmux_config="$HOME/.tmux.conf"
[[ -f "$tmux_source" && ! -L "$tmux_source" ]] || { echo "Missing repo tmux config: $tmux_source" >&2; exit 1; }
[[ ! -d "$tmux_config" || -L "$tmux_config" ]] || { echo "Expected a file at $tmux_config; leaving the directory untouched." >&2; exit 1; }
cp "$tmux_source" "$_dotfiles_download_dir/tmux.conf"
rm -f -- "$tmux_config"
mv "$_dotfiles_download_dir/tmux.conf" "$tmux_config"
echo 'tmux config applied; for an existing server, run: tmux source-file ~/.tmux.conf'
