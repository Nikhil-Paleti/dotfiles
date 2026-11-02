# Install tmux and use the repo config at its standard user path.
install_tool "tmux" tmux
tmux_source="$DOTFILES_ROOT/config/tmux/tmux.conf"
[[ -f "$tmux_source" && ! -L "$tmux_source" ]] || { echo "Missing repo tmux config: $tmux_source" >&2; exit 1; }
tmux_stage="$_dotfiles_download_dir/tmux.conf"
cp "$tmux_source" "$tmux_stage"
tmux_config="$HOME/.tmux.conf"
tmux_backup=''
if [[ -e "$tmux_config" || -L "$tmux_config" ]]; then
  tmux_backup="${tmux_config}_backup"
  suffix=1
  while [[ -e "$tmux_backup" || -L "$tmux_backup" ]]; do
    tmux_backup="${tmux_config}_backup.$suffix"
    suffix=$((suffix + 1))
  done
  printf 'Backing up existing tmux config to: %s\n' "$tmux_backup"
  mv "$tmux_config" "$tmux_backup"
fi
if [[ -e "$tmux_config" || -L "$tmux_config" ]] || ! mv "$tmux_stage" "$tmux_config"; then
  echo 'Could not install tmux config.' >&2
  if [[ -n "$tmux_backup" ]]; then
    if [[ ! -e "$tmux_config" && ! -L "$tmux_config" ]] && mv "$tmux_backup" "$tmux_config"; then
      echo 'Previous tmux config restored.' >&2
    else
      printf 'Previous tmux config is at %s; restore it to %s after moving any replacement aside.\n' "$tmux_backup" "$tmux_config" >&2
    fi
  fi
  exit 1
fi
echo 'tmux config installed at ~/.tmux.conf; for an existing server, run: tmux source-file ~/.tmux.conf'
