# Keyboard layer on WSL (sourced by scripts/install/keyboard.sh): the config is copied to
# %APPDATA%\kanata\kanata.kbd, so Windows Kanata finds it without WSL running at login.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
source "$DOTFILES_ROOT/scripts/lib/kanata.sh"
win_appdata=$(win_appdata_path)
if [[ -n "$win_appdata" ]] && win_kanata_dir=$(wslpath -u "$win_appdata\\kanata" 2>/dev/null); then
  mkdir -p "$win_kanata_dir"
  if cmp -s "$kanata_src" "$win_kanata_dir/kanata.kbd"; then
    ok 'Windows config current'
  else
    cp "$kanata_src" "$win_kanata_dir/kanata.kbd"
    ok "copied to $win_appdata\\kanata\\kanata.kbd"
    note 'If Kanata is running on Windows, pick Reload in its tray icon menu.'
  fi
else
  fail 'could not find the Windows user folder from WSL (cmd.exe interop off?)'
  warn "Copy $kanata_src to %APPDATA%\\kanata\\kanata.kbd by hand."
fi
