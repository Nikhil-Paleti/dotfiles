# `dot kb start|stop|status`: the Kanata keyboard layer, on whichever machine runs it. Status
# asks launchd (Mac) or Windows' task list (WSL) what's running now; it never reads the log.
# Setup and the macOS approvals stay in install.sh (dot update).
# shellcheck disable=SC2154 # kanata_* paths come from scripts/lib/kanata.sh
source "$DOTFILES_ROOT/scripts/lib/kanata.sh"

kb_where() {
  case "$(uname -s)" in
    Darwin) echo mac ;;
    Linux) case "$(uname -r)" in *[Mm]icrosoft*) echo wsl ;; *) echo linux ;; esac ;;
    *) echo other ;;
  esac
}

dot_kb() {
  local action=${1:-status} where
  case "$action" in start|stop|status) ;; *) echo 'Usage: dot kb [status|start|stop]  (dot kb --help)' >&2; return 2 ;; esac
  where=$(kb_where)
  case "$where" in
    mac|wsl) "kb_${where}_$action" ;;
    *)
      echo 'Kanata runs on the Mac or Windows machine with the keyboard, not here.'
      [[ "$action" == status ]]
      ;;
  esac
}

# --- Mac: the LaunchDaemons install.sh sets up, one Kanata for the ROG keyboard and one for
# the built-in keyboard (when this Mac has one).

# Each Mac Kanata as "label plist names-file what", one per line.
kb_mac_daemons() {
  printf '%s %s %s %s\n' "$kanata_label" "$kanata_plist" "$kanata_names" rog
  [[ ! -f "$kanata_builtin_plist" ]] || printf '%s %s %s %s\n' "$kanata_builtin_label" "$kanata_builtin_plist" "$kanata_builtin_names" built-in
}

# One line per Kanata as launchd sees it now; returns 0 only when all of them are running.
kb_mac_report() {
  local label plist names what pid code grabs name status=0
  if [[ ! -f "$kanata_plist" ]]; then
    echo 'Kanata is not set up on this Mac. Run dot update in a terminal.'
    return 1
  fi
  while read -r label plist names what; do
    if [[ "$what" == built-in ]]; then name="The built-in keyboard's Kanata"; else name='Kanata'; fi
    if ! kb_loaded "$label"; then
      echo "$name is stopped. Start it with dot kb start."
      status=1
    elif kanata_running "$label"; then
      pid=$(kb_field "$label" pid)
      grabs=$(kanata_grabs "$names")
      if [[ "$what" == built-in ]]; then echo "$name is running (pid $pid)."
      else echo "Kanata is running (pid $pid) on ${grabs:-every keyboard but the built-in one}."; fi
    else
      code=$(kb_field "$label" 'last exit code')
      echo "$name is loaded but not running${code:+ (last exit code $code)}."
      echo 'Run dot update in a terminal; it checks the driver and the macOS approvals.'
      status=1
    fi
  done < <(kb_mac_daemons)
  if ((status == 0)) && ! kb_loaded "$vhid_label"; then
    echo "! The Karabiner driver daemon is not loaded, so keys won't reach macOS. Run dot kb start." >&2
  fi
  return "$status"
}

kb_mac_status() { kb_mac_report; }

kb_mac_all_running() {
  local label _
  while read -r label _; do if ! kanata_running "$label"; then return 1; fi; done < <(kb_mac_daemons)
}

kb_mac_start() {
  local label plist _
  if [[ ! -f "$kanata_plist" ]]; then kb_mac_report; return; fi
  if kb_mac_all_running; then kb_mac_report; return; fi
  sudo -v -p 'Password to start Kanata: ' || return 1
  # Kanata sends keys through the driver's daemon, so that goes first.
  if [[ -f "$vhid_plist" ]] && ! kb_loaded "$vhid_label"; then
    if kb_disabled "$vhid_label"; then sudo launchctl enable "system/$vhid_label" || true; fi
    sudo launchctl bootstrap system "$vhid_plist" || true
  fi
  while read -r label plist _; do
    if kanata_running "$label"; then continue; fi
    if kb_loaded "$label"; then
      sudo launchctl kickstart "system/$label" || true
    else
      # A switched-off service can't be bootstrapped ("Bootstrap failed: 5").
      if kb_disabled "$label"; then sudo launchctl enable "system/$label" || true; fi
      sudo launchctl bootstrap system "$plist" || true
    fi
  done < <(kb_mac_daemons)
  # launchctl's own error, if any, is above; the report below says where Kanata stands.
  # Started is not enough: a missing approval makes Kanata quit within a second or two.
  for _ in {1..10}; do kb_mac_all_running && break; sleep 1; done
  sleep 2
  kb_mac_report
}

kb_mac_stop() {
  local label plist _ left=''
  while read -r label _; do if kb_loaded "$label"; then left=1; fi; done < <(kb_mac_daemons)
  if [[ -z "$left" ]]; then echo 'Kanata is already stopped.'; return 0; fi
  sudo -v -p 'Password to stop Kanata: ' || return 1
  while read -r label plist _; do
    if kb_loaded "$label"; then sudo launchctl bootout "system/$label" || true; fi
  done < <(kb_mac_daemons)
  for _ in {1..10}; do
    left=''
    while read -r label _; do if kb_loaded "$label"; then left=1; fi; done < <(kb_mac_daemons)
    [[ -n "$left" ]] || break
    sleep 1
  done
  if [[ -n "$left" ]]; then echo 'Kanata did not stop.' >&2; return 1; fi
  echo 'Kanata stopped on every keyboard, so Caps Lock is plain Caps Lock again.'
  echo 'It starts again with dot kb start, or when the Mac restarts.'
}

# --- WSL: Kanata runs on Windows, started from the Startup-folder shortcut in
# config/kanata/README.md.

kb_wsl_startup_link() {
  local appdata
  appdata=$(win_appdata_path)
  [[ -n "$appdata" ]] || return 1
  printf '%s' "$appdata\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\Kanata.lnk"
}

kb_wsl_status() {
  local procs
  procs=$(win_kanata_procs)
  if [[ -n "$procs" ]]; then
    echo "Kanata is running on Windows ($(awk '{ printf "%s%s pid %s", sep, $1, $2; sep = ", " }' <<<"$procs"))."
    return 0
  fi
  echo 'Kanata is not running on Windows. Start it with dot kb start.'
  return 1
}

kb_wsl_start() {
  local link link_wsl ps_link _
  if [[ -n "$(win_kanata_procs)" ]]; then kb_wsl_status; return; fi
  if ! link=$(kb_wsl_startup_link) || ! link_wsl=$(wslpath -u "$link" 2>/dev/null) || [[ ! -f "$link_wsl" ]]; then
    echo 'No Kanata shortcut in the Windows Startup folder. Set it up with the Windows steps in' >&2
    echo "$DOTFILES_ROOT/config/kanata/README.md, then run dot kb start." >&2
    return 1
  fi
  # Single quotes in a PowerShell string are written twice.
  ps_link=${link//\'/\'\'}
  win_run powershell.exe -NoProfile -NonInteractive -Command "Start-Process -FilePath '$ps_link'" >/dev/null 2>&1 || true
  for _ in {1..10}; do [[ -z "$(win_kanata_procs)" ]] || break; sleep 1; done
  kb_wsl_status
}

kb_wsl_stop() {
  local name _
  if [[ -z "$(win_kanata_procs)" ]]; then echo 'Kanata is already stopped on Windows.'; return 0; fi
  while read -r name _; do
    win_run taskkill.exe /F /IM "$name" >/dev/null 2>&1 || true
  done < <(win_kanata_procs)
  for _ in {1..5}; do [[ -n "$(win_kanata_procs)" ]] || break; sleep 1; done
  if [[ -n "$(win_kanata_procs)" ]]; then
    echo 'Kanata did not stop. If it runs as administrator, quit it from its tray icon.' >&2
    return 1
  fi
  echo 'Kanata stopped on Windows. It starts again with dot kb start, or at your next Windows login.'
}
