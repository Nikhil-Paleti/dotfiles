# Install the small zsh setup before changing the user's login shell.
install_tool "zsh" zsh
brew_prefix="$(brew --prefix)"
for plugin in "${zsh_plugins[@]}"; do
  if ! brew list --formula --versions "$plugin" >/dev/null 2>&1; then
    brew install "$plugin"
  fi
  [[ -r "$brew_prefix/share/$plugin/$plugin.zsh" ]] || {
    echo "Missing $plugin script under $brew_prefix/share; check the Homebrew installation." >&2; exit 1;
  }
done

# Only this dedicated file is managed; never replace an existing zshrc.
zsh_config="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/zshrc"
zsh_marker='# Managed by Nikhil-Paleti/dotfiles: zsh setup'
[[ ! -L "$zsh_config" && ( ! -e "$zsh_config" || -f "$zsh_config" ) ]] || {
  echo "Refusing to replace non-regular $zsh_config" >&2; exit 1;
}
if [[ -f "$zsh_config" ]] && [[ "$(head -n 1 "$zsh_config")" != "$zsh_marker" ]]; then
  echo "Refusing to replace unmanaged $zsh_config; move it aside first." >&2; exit 1
fi
{
  printf '%s\n' "$zsh_marker"
  printf 'export HOMEBREW_PREFIX=%q\n' "$brew_prefix"
  # Explicit zsh output also works when this Bash installer was launched from Bash.
  printf 'eval "$(%q shellenv zsh)"\n' "$(command -v brew)"
  cat "$DOTFILES_ROOT/config/zsh/zshrc"
} > "$_dotfiles_download_dir/zshrc"
mkdir -p "$(dirname "$zsh_config")" "$(dirname "$zshrc")"
cp "$_dotfiles_download_dir/zshrc" "$zsh_config"
printf -v zsh_loader '[[ ! -r %q ]] || source %q' "$zsh_config" "$zsh_config"
if ! grep -Fqx -- "$zsh_loader" "$zshrc" 2>/dev/null; then
  if [[ -f "$zshrc" ]]; then
    zsh_backup="$(mktemp "${zshrc}.before-dotfiles.XXXXXX")"
    cp -p "$zshrc" "$zsh_backup"
    printf 'Preserved existing zshrc in %s\n' "$zsh_backup"
  fi
  printf '\n%s\n' "$zsh_loader" >> "$zshrc"
fi
