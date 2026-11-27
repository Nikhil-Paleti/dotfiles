# Keyboard layer on WSL (sourced by scripts/install/keyboard.sh): the config is copied to
# %APPDATA%\kanata\kanata.kbd, so Windows Kanata finds it without WSL running at login.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
cmd_exe=$(command -v cmd.exe || echo /mnt/c/Windows/System32/cmd.exe)
# Run from cmd.exe's own (Windows) folder: it warns about a WSL working directory.
win_appdata=$(cd "$(dirname "$cmd_exe")" 2>/dev/null && "$cmd_exe" /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r') ||
  win_appdata=''
if [[ "$win_appdata" == [A-Za-z]:\\* ]] && win_kanata_dir=$(wslpath -u "$win_appdata\\kanata" 2>/dev/null); then
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
