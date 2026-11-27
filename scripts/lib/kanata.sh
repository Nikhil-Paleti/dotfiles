# Where the keyboard layer lives and how to ask whether it's running, shared by the installer
# (scripts/install/keyboard-*.sh) and `dot kb`. Definitions only; nothing runs here.
# shellcheck disable=SC2034 # read by the files that source this one
kanata_label=dev.kanata.kanata
kanata_bin=/usr/local/bin/kanata
kanata_dir="${XDG_CONFIG_HOME:-$HOME/.config}/kanata"
kanata_cfg="$kanata_dir/kanata.kbd"
# Keyboards Kanata grabs on the Mac, one per line as `kanata --list` prints them; empty means all.
kanata_names="$kanata_dir/macos-keyboards.txt"
kanata_log=/var/log/kanata.log
kanata_plist=/Library/LaunchDaemons/dev.kanata.kanata.plist
vhid_label=org.pqrs.Karabiner-VirtualHIDDevice-Daemon
vhid_plist=/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist

# Whether launchd has the system service $1 loaded: a matching plist on disk doesn't mean it
# is (a manual `launchctl bootout` leaves the file behind).
kb_loaded() { launchctl print "system/$1" >/dev/null 2>&1; }
# A field of a loaded system service as launchd reports it now: kb_field LABEL 'last exit code'.
kb_field() {
  launchctl print "system/$1" 2>/dev/null |
    awk -v key="$2" '{ sub(/^[[:space:]]+/, "") } index($0, key " = ") == 1 { print substr($0, length(key) + 4); exit }'
}
# Whether Kanata is running right now (launchd's view, not the log).
kanata_running() { [[ "$(kb_field "$kanata_label" state)" == running ]]; }
# Whether launchd has the service switched off, so a bootstrap of it fails.
kb_disabled() { launchctl print-disabled system 2>/dev/null | grep -Eq "\"$1\" => (true|disabled)"; }
# The keyboards Kanata grabs on the Mac, comma separated; empty means every keyboard.
kanata_grabs() { grep -vE '^(#|$)' "$kanata_names" 2>/dev/null | paste -sd ',' - | sed 's/,/, /g' || true; }

# WSL: Windows runs Kanata. cmd.exe runs from its own (Windows) folder, since it warns about
# a WSL working directory.
win_run() {
  local cmd_exe
  cmd_exe=$(command -v cmd.exe || echo /mnt/c/Windows/System32/cmd.exe)
  (cd "$(dirname "$cmd_exe")" 2>/dev/null && "$@")
}
# %APPDATA% as a Windows path (C:\Users\...), or nothing if WSL can't reach Windows.
win_appdata_path() {
  local appdata
  appdata=$(win_run cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r') || return 0
  [[ "$appdata" != [A-Za-z]:\\* ]] || printf '%s' "$appdata"
}
# The Kanata processes running on Windows, as "image-name pid" lines.
win_kanata_procs() {
  win_run tasklist.exe /FO CSV /NH 2>/dev/null | tr -d '\r' |
    awk -F '","' 'tolower($1) ~ /^"kanata/ { sub(/^"/, "", $1); print $1, $2 }' || true
}
