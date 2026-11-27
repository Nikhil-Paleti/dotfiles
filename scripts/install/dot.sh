# The dot command (bin/dot): linked into ~/.local/bin so it works from any folder, and that
# folder put on PATH for future shells unless the startup file already names it.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
step 'dot command'
dot_bin_dir="$HOME/.local/bin"
dot_link="$dot_bin_dir/dot"
mkdir -p "$dot_bin_dir"
if [[ -e "$dot_link" && ! -L "$dot_link" ]]; then
  fail "$(short_path "$dot_link") is another program"
  warn "Move $(short_path "$dot_link") aside, then rerun to link dot there."
else
  # A link from an older checkout points here now.
  [[ "$(readlink "$dot_link" 2>/dev/null || true)" == "$DOTFILES_ROOT/bin/dot" ]] ||
    ln -sfn "$DOTFILES_ROOT/bin/dot" "$dot_link"
  # Above the lines that must stay last (scripts/install/shell.sh).
  case "$login_shell" in bash) dot_anchor='ble-attach' ;; *) dot_anchor='zsh-syntax-highlighting\.zsh' ;; esac
  # shellcheck disable=SC2016 # written literally; expands when the shell starts
  grep -Eqs '\.local/bin' "$shell_rc" ||
    rc_add_before "$shell_rc" '\.local/bin' \
      'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac' "$dot_anchor"
  ok "$(short_path "$dot_link")"
fi
