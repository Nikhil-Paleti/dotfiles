# Keyboard layer on macOS (sourced by scripts/install/keyboard.sh): the Karabiner driver, kanata
# in /usr/local/bin and two LaunchDaemons, as in Kanata's docs/setup-macos.md, with sudo asked
# once and only when something is out of date, then a walk-through of any missing System
# Settings approvals. The plists are templates in config/kanata/macos.
# Kanata 1.12.0 speaks only to driver 6.2.0 (1.13 moves to driver 8): bump both together.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
kanata_version=1.12.0
vhid_version=6.2.0
vhid_sha256=9e8c46239f0748161241e42444857901224e5c82f5b58a1731df4c70bf0736a8
case "$(uname -m)" in
  arm64) kanata_arch=arm64; kanata_zip_sha256=839769d189911b5881e11550eaa2039705213fb725865d088f5a2e3a6c10de32 ;;
  *) kanata_arch=x64; kanata_zip_sha256=bdb8b2f7ae2a648336a2561c7c6c00a736cd76e012035df651114b304c5ffb01 ;;
esac
kanata_bin=/usr/local/bin/kanata
kanata_dir="${XDG_CONFIG_HOME:-$HOME/.config}/kanata"
kanata_cfg="$kanata_dir/kanata.kbd"
# Keyboards Kanata grabs, one per line as `kanata --list` prints them; empty means all.
kanata_names="$kanata_dir/macos-keyboards.txt"
kanata_log=/var/log/kanata.log
vhid_root='/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice'
vhid_manager=/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager
vhid_plist=/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist
kanata_plist=/Library/LaunchDaemons/dev.kanata.kanata.plist
kb_tmp="$_dotfiles_download_dir/keyboard"
mkdir -p "$kb_tmp" "$kanata_dir"
verify_sha256() { # file, expected
  [[ "$(shasum -a 256 "$1" | cut -d ' ' -f 1)" == "$2" ]] || die "Checksum mismatch for $1; not installing it."
}
# A plist from config/kanata/macos with each @NAME@ replaced: kb_render FILE NAME=value...
kb_render() {
  local template="$DOTFILES_ROOT/config/kanata/macos/$1"
  shift
  # shellcheck disable=SC2016 # an awk program, not shell
  env "$@" awk -v names="${*%%=*}" '
    BEGIN { n = split(names, name, " ") }
    {
      for (i = 1; i <= n; i++) {
        mark = "@" name[i] "@"
        while ((at = index($0, mark)) > 0) $0 = substr($0, 1, at - 1) ENVIRON[name[i]] substr($0, at + length(mark))
      }
      print
    }' "$template"
}
# The first root step asks for the password; a background loop keeps sudo fresh after that.
kb_sudo_keepalive=''
kb_sudo() {
  if [[ -z "$kb_sudo_keepalive" ]]; then
    run_live sudo -v -p 'Password for the keyboard layer (asked once): ' || die 'sudo failed; keyboard layer not set up.'
    ( while kill -0 "$$" 2>/dev/null && sudo -n -v 2>/dev/null; do sleep 30; done ) >/dev/null 2>&1 &
    kb_sudo_keepalive=$!
  fi
  sudo "$@"
}
# Whether launchd has the system service $1 loaded: a matching plist on disk doesn't mean it
# is (a manual `launchctl bootout` leaves the file behind).
kb_loaded() { launchctl print "system/$1" >/dev/null 2>&1; }
# The repo config with the names from $kanata_names in place of its marker line.
kanata_render() {
  local names='' line
  if [[ -f "$kanata_names" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -n "$line" && "$line" != \#* ]] || continue
      if [[ "$line" == *'"'* ]]; then warn "Skipping keyboard name with a quote in $kanata_names: $line"; continue; fi
      names+=" \"$line\""
    done <"$kanata_names"
  fi
  if [[ -n "$names" ]]; then
    KB_NAMES="${names# }" awk '/;; @macos-keyboards@/ {
      print "  macos-dev-names-include (" ENVIRON["KB_NAMES"] ")"
      print "  macos-continue-if-no-devs-found yes"
      next
    } { print }' "$kanata_src"
  else
    cat "$kanata_src"
  fi
}
# kanata (a root daemon) reads the rendered config from $kanata_cfg.
kanata_cfg_changed=false
kanata_apply_config() {
  kanata_render >"$kb_tmp/kanata.kbd"
  if ! cmp -s "$kb_tmp/kanata.kbd" "$kanata_cfg"; then
    cp "$kb_tmp/kanata.kbd" "$kanata_cfg"
    kanata_cfg_changed=true
  fi
  detail "Kanata config applied: $kanata_cfg"
}
kanata_read_log() { if [[ -r "$kanata_log" ]]; then cat "$kanata_log"; else sudo -n cat "$kanata_log" 2>/dev/null || true; fi; }
kanata_log_lines() { kanata_read_log | wc -l | tr -d ' '; }
# How the newest Kanata start after log line $1 went: ok, waiting (no listed keyboard is
# plugged in), input-monitoring, accessibility, driver, grab-failed, pending or none.
kanata_outcome() {
  local after="$1" start run
  start=$(kanata_read_log | awk -v after="$after" 'NR > after && /kanata v[0-9.]+ starting/ { n = NR } END { print n }')
  [[ -n "$start" ]] || { echo none; return 0; }
  run=$(kanata_read_log | tail -n "+$start")
  case "$run" in
    *'Starting kanata proper'*) echo ok ;;
    *'Polling for device connection'*|*'Waiting for device connection'*) echo waiting ;;
    *'Input Monitoring permission'*) echo input-monitoring ;;
    *'needs macOS Accessibility'*|*'Accessibility permission request failed'*) echo accessibility ;;
    *'driver is not activated'*) echo driver ;;
    *'grab failed'*) echo grab-failed ;;
    *) echo pending ;;
  esac
}
# Wait up to 20 s for the start after log line $1 to settle; sets kanata_state. Not run in
# $(...), so kb_sudo stays in this shell and asks for the password once.
kanata_state=none
kanata_wait_outcome() {
  local _
  for _ in {1..20}; do
    kanata_state=$(kanata_outcome "$1")
    [[ "$kanata_state" == pending || "$kanata_state" == none ]] || break
    sleep 1
  done
}
# Whether Kanata is running right now (launchd's view, not the log).
kanata_running() { launchctl print system/dev.kanata.kanata 2>/dev/null | grep -qE '^[[:space:]]*state = running'; }
# Restart Kanata, loading its service first if launchd doesn't have it, and judge only the
# log lines this start writes.
kanata_restart() {
  local before
  before=$(kanata_log_lines)
  if kb_loaded dev.kanata.kanata; then
    kb_sudo launchctl kickstart -k system/dev.kanata.kanata
  else
    kb_sudo launchctl bootstrap system "$kanata_plist"
  fi
  kanata_wait_outcome "$before"
}
# Caps Lock is Esc on the built-in keyboard too, which Kanata leaves alone: macOS's hidutil
# remapping (Apple TN2450) from a login item, as it lasts only until restart. No sudo. It
# replaces other mappings on that keyboard (System Settings > Keyboard > Modifier Keys).
capsesc_plist="$HOME/Library/LaunchAgents/dev.dotfiles.capslock-esc.plist"
capsesc_map='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771129,"HIDKeyboardModifierMappingDst":30064771113}]}'
kb_render dev.dotfiles.capslock-esc.plist CAPSESC_MAP="$capsesc_map" >"$kb_tmp/capsesc.plist"
if [[ -n "${CI:-}" ]]; then
  detail 'CI: Caps Lock to Esc login item skipped (needs a login session).'
elif ! cmp -s "$kb_tmp/capsesc.plist" "$capsesc_plist"; then
  mkdir -p "$(dirname "$capsesc_plist")"
  cp "$kb_tmp/capsesc.plist" "$capsesc_plist"
  launchctl bootout "gui/$(id -u)" "$capsesc_plist" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$capsesc_plist" ||
    hidutil property --matching '{"Built-In":true}' --set "$capsesc_map" >/dev/null
  note "Caps Lock is now Esc on the built-in keyboard (login item: $(short_path "$capsesc_plist"))."
fi
if [[ -n "${CI:-}" ]]; then
  kanata_apply_config
  # The LaunchDaemons need sudo and a real keyboard, so CI only checks that they render.
  kb_render org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist VHID_ROOT="$vhid_root" >"$kb_tmp/vhid.plist"
  kb_render dev.kanata.kanata.plist KANATA_BIN="$kanata_bin" KANATA_CFG="$kanata_cfg" KANATA_LOG="$kanata_log" >"$kb_tmp/kanata.plist"
  run plutil -lint "$kb_tmp/capsesc.plist" "$kb_tmp/vhid.plist" "$kb_tmp/kanata.plist"
  ok 'config and plists only in CI'
elif [[ -d /Applications/Karabiner-Elements.app ]]; then
  kanata_apply_config
  fail 'Karabiner-Elements is installed'
  warn 'It ships its own driver and grabs the keyboard, so it cannot run beside Kanata.' \
    'Uninstall it (its menu: Uninstall), then rerun.'
else
  kanata_bin_changed=false
  kb_fresh=false
  # 1. The driver Kanata sends keys through, from its official signed package.
  vhid_installed=$(pkgutil --pkg-info org.pqrs.Karabiner-DriverKit-VirtualHIDDevice 2>/dev/null | awk '/^version:/ {print $2}' || true)
  if [[ "$vhid_installed" != "$vhid_version" ]]; then
    note "Installing the Karabiner VirtualHIDDevice driver $vhid_version${vhid_installed:+ (replacing $vhid_installed)}."
    curl -fsSL "https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v$vhid_version/Karabiner-DriverKit-VirtualHIDDevice-$vhid_version.pkg" -o "$kb_tmp/vhid.pkg"
    verify_sha256 "$kb_tmp/vhid.pkg" "$vhid_sha256"
    run kb_sudo installer -pkg "$kb_tmp/vhid.pkg" -target /
    run kb_sudo "$vhid_manager" forceActivate
  fi
  # 2. The driver's daemon, which Karabiner-Elements would otherwise run.
  kb_render org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist VHID_ROOT="$vhid_root" >"$kb_tmp/vhid.plist"
  if ! cmp -s "$kb_tmp/vhid.plist" "$vhid_plist" || ! kb_loaded org.pqrs.Karabiner-VirtualHIDDevice-Daemon; then
    kb_sudo install -m 644 -o root -g wheel "$kb_tmp/vhid.plist" "$vhid_plist"
    kb_sudo launchctl bootout system "$vhid_plist" 2>/dev/null || true
    kb_sudo launchctl bootstrap system "$vhid_plist"
    detail "Driver daemon LaunchDaemon installed: $vhid_plist"
  fi
  # 3. kanata from its release, the build without cmd actions so the user-writable config
  # can't run commands as root. Root-owned, as the daemon runs it.
  kanata_installed=$("$kanata_bin" --version 2>/dev/null || true)
  if [[ "$kanata_installed" != "kanata $kanata_version" ]]; then
    note "Installing kanata $kanata_version to $kanata_bin."
    curl -fsSL "https://github.com/jtroo/kanata/releases/download/v$kanata_version/macos-binaries-$kanata_arch.zip" -o "$kb_tmp/kanata.zip"
    verify_sha256 "$kb_tmp/kanata.zip" "$kanata_zip_sha256"
    unzip -p "$kb_tmp/kanata.zip" "kanata_macos_$kanata_arch" >"$kb_tmp/kanata"
    kb_sudo install -d -m 755 -o root -g wheel "$(dirname "$kanata_bin")"
    kb_sudo install -m 755 -o root -g wheel "$kb_tmp/kanata" "$kanata_bin"
    kanata_bin_changed=true
  fi
  # 4. ROG/ASUS keyboards plugged in now join the list. Only listed keyboards are picked up
  # when plugged in after Kanata starts (see the config).
  [[ -f "$kanata_names" ]] || echo '# Keyboards Kanata grabs, one name per line, as kanata --list prints them.' >"$kanata_names"
  while IFS= read -r kb_name; do
    [[ -n "$kb_name" ]] || continue
    grep -qxF -- "$kb_name" "$kanata_names" || { printf '%s\n' "$kb_name" >>"$kanata_names"; note "Kanata will grab this keyboard: $kb_name ($(short_path "$kanata_names"))"; }
  done < <({ "$kanata_bin" --list 2>/dev/null || sudo -n "$kanata_bin" --list 2>/dev/null; } | sed -nE 's/^0x[0-9A-Fa-f]+ +[0-9]+ +[0-9]+ +//p' | sed -E 's/[[:space:]]+$//' | grep -iE 'rog|asus' | sort -u || true)
  grep -qvE '^(#|$)' "$kanata_names" || detail 'No ROG/ASUS keyboard found, so Kanata grabs every keyboard. Plug it in and rerun to grab only it.'
  kanata_apply_config
  "$kanata_bin" --check -c "$kanata_cfg" >/dev/null || die "Kanata rejected $kanata_cfg; fix it, then rerun."
  # 5. kanata itself, as root at boot (it must be root to reach the driver).
  kb_render dev.kanata.kanata.plist KANATA_BIN="$kanata_bin" KANATA_CFG="$kanata_cfg" KANATA_LOG="$kanata_log" >"$kb_tmp/kanata.plist"
  kanata_before=$(kanata_log_lines)
  if ! cmp -s "$kb_tmp/kanata.plist" "$kanata_plist" || ! kb_loaded dev.kanata.kanata; then
    kb_sudo install -m 644 -o root -g wheel "$kb_tmp/kanata.plist" "$kanata_plist"
    kb_sudo launchctl bootout system "$kanata_plist" 2>/dev/null || true
    kb_sudo launchctl bootstrap system "$kanata_plist"
    detail "Kanata LaunchDaemon installed: $kanata_plist (log: $kanata_log)"
    kb_fresh=true
    kanata_wait_outcome "$kanata_before"
  elif [[ "$kanata_cfg_changed" == true || "$kanata_bin_changed" == true ]]; then
    detail 'Restarting Kanata with the new config.'
    kanata_restart
  else
    # Nothing changed. The log's newest start describes Kanata only while it is running; an
    # old success in the log says nothing about a Kanata that has since stopped.
    kanata_state=none
    if kanata_running; then kanata_state=$(kanata_outcome 0); fi
    if [[ "$kanata_state" != ok && "$kanata_state" != waiting && -t 0 ]]; then kanata_restart; fi
  fi
  # 6. The one-time macOS approvals, one System Settings window at a time.
  if [[ "$kanata_state" != ok && "$kanata_state" != waiting ]]; then
    kb_panes=()
    systemextensionsctl list 2>/dev/null | grep -F org.pqrs.Karabiner-DriverKit-VirtualHIDDevice | grep -qF '[activated enabled]' ||
      kb_panes+=(driver)
    kb_panes+=(input-monitoring accessibility)
    if [[ -t 0 && -t 1 ]]; then
      kb_fresh=true
      note '' "Kanata needs ${#kb_panes[@]} one-time macOS approvals. Each System Settings window opens in turn;" \
        'do what is printed here, then come back and press Enter.'
      printf '%s' "$kanata_bin" | pbcopy 2>/dev/null || true
      kb_step=0
      for kb_pane in "${kb_panes[@]}"; do
        kb_step=$((kb_step + 1))
        case "$kb_pane" in
          driver)
            note '' "$kb_step/${#kb_panes[@]} Driver Extensions (opening Login Items & Extensions)" \
              '  Scroll down to Extensions and click the (i) next to Driver Extensions.' \
              '  Switch on Karabiner-DriverKit-VirtualHIDDevice, enter your password, then click Done.' \
              '  (macOS 14 and older: Privacy & Security shows "System software ... was blocked"; click Allow.)'
            open 'x-apple.systempreferences:com.apple.LoginItems-Settings.extension' 2>/dev/null || true ;;
          input-monitoring|accessibility)
            if [[ "$kb_pane" == input-monitoring ]]; then kb_title='Input Monitoring' kb_anchor=Privacy_ListenEvent
            else kb_title='Accessibility' kb_anchor=Privacy_Accessibility; fi
            note '' "$kb_step/${#kb_panes[@]} $kb_title (opening Privacy & Security > $kb_title)" \
              '  If kanata is in the list, switch it on and you are done here.' \
              "  If it's missing: click +, press Cmd+Shift+G, paste $kanata_bin (it's on your" \
              '  clipboard), press Enter, click Open, and switch it on.' \
              '  If it was already on and Kanata still failed: select it, click -, then add it as above.'
            open "x-apple.systempreferences:com.apple.preference.security?$kb_anchor" 2>/dev/null || true ;;
        esac
        read -r -p '    Press Enter when done. ' _ || true
      done
      note 'Restarting Kanata to check the approvals.'
      kanata_restart
    fi
  fi
  kanata_grabs=$(grep -vE '^(#|$)' "$kanata_names" | paste -sd ',' - | sed 's/,/, /g' || true)
  case "$kanata_state" in
    ok) ok "running on ${kanata_grabs:-every keyboard}" ;;
    waiting) ok "running; plug in $kanata_grabs to start the layer" ;;
    input-monitoring) fail 'Kanata lacks Input Monitoring' ;;
    accessibility) fail 'Kanata lacks Accessibility' ;;
    driver) fail 'the Karabiner driver is not switched on (Driver Extensions)' ;;
    grab-failed) fail 'Kanata could not grab the keyboard' ;;
    none) fail 'Kanata is not running' ;;
    *) fail "Kanata has not reported in; check $kanata_log" ;;
  esac
  case "$kanata_state" in
    ok|waiting) ;;
    grab-failed) warn 'Remove kanata (-) from Input Monitoring and Accessibility, then rerun bash install.sh in a terminal to add it back.' ;;
    none) warn 'Rerun bash install.sh in a terminal to start it.' ;;
    *) warn 'Rerun bash install.sh in a terminal; it walks you through each System Settings window.' ;;
  esac
  if [[ "$kb_fresh" == true ]]; then
    note 'Hold Left Ctrl + Space + Esc together to quit Kanata if the keyboard ever misbehaves.'
  fi
fi
[[ -z "${kb_sudo_keepalive:-}" ]] || kill "$kb_sudo_keepalive" 2>/dev/null || true
