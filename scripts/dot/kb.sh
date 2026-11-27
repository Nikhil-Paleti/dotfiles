# `dot kb start|stop|restart|status`: the Kanata keyboard layer, on whichever machine runs it. Status
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
  case "$action" in start|stop|restart|status) ;; *) echo 'Usage: dot kb [status|start|stop|restart]  (dot kb --help)' >&2; return 2 ;; esac
  where=$(kb_where)
  case "$where" in
    mac|wsl) "kb_${where}_$action" ;;
    *)
      echo 'Kanata runs on the Mac or Windows machine with the keyboard, not here.'
      [[ "$action" == status ]]
      ;;
  esac
}

# --- Mac: the LaunchDaemon install.sh sets up.

# One line on Kanata as launchd sees it now; returns 0 only when it's running.
kb_mac_report() {
  local pid code
  if [[ ! -f "$kanata_plist" ]]; then
    echo 'Kanata is not set up on this Mac. Run dot update in a terminal.'
    return 1
  fi
  if ! kb_loaded "$kanata_label"; then
    echo 'Kanata is stopped. Start it with dot kb start.'
    return 1
  fi
  if kanata_running; then
    pid=$(kb_field "$kanata_label" pid)
    echo "Kanata is running (pid $pid) on every keyboard."
    if ! kb_loaded "$vhid_label"; then
      echo "! The Karabiner driver daemon is not loaded, so keys won't reach macOS. Run dot kb start." >&2
    fi
    return 0
  fi
  code=$(kb_field "$kanata_label" 'last exit code')
  echo "Kanata is loaded but not running${code:+ (last exit code $code)}."
  echo 'Run dot update in a terminal; it checks the driver and the macOS approvals.'
  return 1
}

kb_mac_status() { kb_mac_report; }

kb_mac_start() {
  if [[ ! -f "$kanata_plist" ]]; then kb_mac_report; return; fi
  if kanata_running; then kb_mac_report; return; fi
  sudo -v -p 'Password to start Kanata: ' || return 1
  # Kanata sends keys through the driver's daemon, so that goes first.
  if [[ -f "$vhid_plist" ]] && ! kb_loaded "$vhid_label"; then
    if kb_disabled "$vhid_label"; then sudo launchctl enable "system/$vhid_label" || true; fi
    sudo launchctl bootstrap system "$vhid_plist" || true
  fi
  if kb_loaded "$kanata_label"; then
    sudo launchctl kickstart "system/$kanata_label" || true
  else
    # A switched-off service can't be bootstrapped ("Bootstrap failed: 5").
    if kb_disabled "$kanata_label"; then sudo launchctl enable "system/$kanata_label" || true; fi
    sudo launchctl bootstrap system "$kanata_plist" || true
  fi
  # launchctl's own error, if any, is above; the report below says where Kanata stands.
  # Started is not enough: a missing approval makes Kanata quit within a second or two.
  local _
  for _ in {1..10}; do kanata_running && break; sleep 1; done
  sleep 2
  kb_mac_report
}

kb_mac_stop() {
  if ! kb_loaded "$kanata_label"; then echo 'Kanata is already stopped.'; return 0; fi
  sudo -v -p 'Password to stop Kanata: ' || return 1
  sudo launchctl bootout "system/$kanata_label" || true
  local _
  for _ in {1..10}; do kb_loaded "$kanata_label" || break; sleep 1; done
  if kb_loaded "$kanata_label"; then echo 'Kanata did not stop.' >&2; return 1; fi
  echo 'Kanata stopped. It starts again with dot kb start, or when the Mac restarts.'
}

# Kanata grabs the keyboards connected when it starts, so a newly plugged-in one needs this.
kb_mac_restart() {
  if ! kb_loaded "$kanata_label"; then kb_mac_start; return; fi
  sudo -v -p 'Password to restart Kanata: ' || return 1
  sudo launchctl kickstart -k "system/$kanata_label" || true
  local _
  for _ in {1..10}; do kanata_running && break; sleep 1; done
  sleep 2
  kb_mac_report
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

kb_wsl_restart() { kb_wsl_stop && kb_wsl_start; }
