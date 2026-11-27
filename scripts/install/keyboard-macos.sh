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
# Paths, kb_loaded and kanata_running are shared with `dot kb`.
source "$DOTFILES_ROOT/scripts/lib/kanata.sh"
kanata_builtin_src="$DOTFILES_ROOT/config/kanata/builtin.kbd"
vhid_root='/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice'
vhid_manager=/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager
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
# The names in a names file as a Kanata list ("a" "b"), skipping comments and quoted names.
kanata_name_list() {
  local names='' line
  if [[ -f "$1" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -n "$line" && "$line" != \#* ]] || continue
      if [[ "$line" == *'"'* ]]; then warn "Skipping keyboard name with a quote in $1: $line"; continue; fi
      names+=" \"$line\""
    done <"$1"
  fi
  printf '%s' "${names# }"
}
# A repo config ($1) with its marker line replaced by $2 (defcfg lines); no $2 keeps it as is.
kanata_fill() {
  if [[ -n "$2" ]]; then
    KB_LINES="$2" awk '/;; @macos-keyboards@/ { print ENVIRON["KB_LINES"]; next } { print }' "$1"
  else
    cat "$1"
  fi
}
# The ROG config: only the listed keyboards, or, with none listed, every keyboard but the
# built-in one, which has its own Kanata.
kanata_render() {
  local names builtin
  names=$(kanata_name_list "$kanata_names")
  builtin=$(kanata_name_list "$kanata_builtin_names")
  if [[ -n "$names" ]]; then
    kanata_fill "$kanata_src" "  macos-dev-names-include ($names)
  macos-continue-if-no-devs-found yes"
  elif [[ -n "$builtin" ]]; then
    kanata_fill "$kanata_src" "  macos-dev-names-exclude ($builtin)
  macos-continue-if-no-devs-found yes"
  else
    kanata_fill "$kanata_src" ''
  fi
}
# The built-in keyboard's config, only ever with its name filled in.
kanata_builtin_render() {
  kanata_fill "$kanata_builtin_src" "  macos-dev-names-include ($(kanata_name_list "$kanata_builtin_names"))
  macos-continue-if-no-devs-found yes"
}
kanata_has_builtin() { [[ -n "$(kanata_name_list "$kanata_builtin_names")" ]]; }
# The Kanata daemons (root) read the rendered configs from $kanata_cfg and $kanata_builtin_cfg.
kanata_cfg_changed=false
kanata_builtin_cfg_changed=false
kanata_apply_config() {
  kanata_render >"$kb_tmp/kanata.kbd"
  if ! cmp -s "$kb_tmp/kanata.kbd" "$kanata_cfg"; then
    cp "$kb_tmp/kanata.kbd" "$kanata_cfg"
    kanata_cfg_changed=true
  fi
  detail "Kanata config applied: $kanata_cfg"
  if kanata_has_builtin; then
    kanata_builtin_render >"$kb_tmp/builtin.kbd"
    if ! cmp -s "$kb_tmp/builtin.kbd" "$kanata_builtin_cfg"; then
      cp "$kb_tmp/builtin.kbd" "$kanata_builtin_cfg"
      kanata_builtin_cfg_changed=true
    fi
    detail "Built-in keyboard config applied: $kanata_builtin_cfg"
  fi
}
# Log helpers take the log to read; the ROG Kanata's by default.
kanata_read_log() {
  local log=${1:-$kanata_log}
  if [[ -r "$log" ]]; then cat "$log"; else sudo -n cat "$log" 2>/dev/null || true; fi
}
kanata_log_lines() { kanata_read_log "${1:-}" | wc -l | tr -d ' '; }
# How the newest Kanata start after log line $1 (of log $2) went: ok, waiting (no listed
# keyboard is plugged in), input-monitoring, accessibility, driver, grab-failed, pending or none.
kanata_outcome() {
  local after="$1" start run
  start=$(kanata_read_log "${2:-}" | awk -v after="$after" 'NR > after && /kanata v[0-9.]+ starting/ { n = NR } END { print n }')
  [[ -n "$start" ]] || { echo none; return 0; }
  run=$(kanata_read_log "${2:-}" | tail -n "+$start")
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
# Wait up to 20 s for the start after log line $1 (of log $2) to settle; sets kanata_last. Not
# run in $(...), so kb_sudo stays in this shell and asks for the password once.
kanata_last=none
kanata_wait_outcome() {
  local _
  for _ in {1..20}; do
    kanata_last=$(kanata_outcome "$1" "${2:-}")
    [[ "$kanata_last" == pending || "$kanata_last" == none ]] || break
    sleep 1
  done
}
# Restart a Kanata (label, plist, log), loading its service first if launchd doesn't have it,
# and judge only the log lines this start writes; sets kanata_last.
kanata_restart() {
  local before
  before=$(kanata_log_lines "$3")
  if kb_loaded "$1"; then
    kb_sudo launchctl kickstart -k "system/$1"
  else
    kb_sudo launchctl bootstrap system "$2"
  fi
  kanata_wait_outcome "$before" "$3"
}
kanata_state=none
kanata_builtin_state=''
kanata_restart_rog() { kanata_restart "$kanata_label" "$kanata_plist" "$kanata_log"; kanata_state=$kanata_last; }
kanata_restart_builtin() {
  kanata_restart "$kanata_builtin_label" "$kanata_builtin_plist" "$kanata_builtin_log"
  kanata_builtin_state=$kanata_last
}
# Caps Lock on the built-in keyboard used to be Esc through a hidutil login item. Its own
# Kanata grabs that keyboard now, so the login item and its remap go: a remap left in place
# would turn Caps Lock into Esc before Kanata sees it, and the layer would never open there.
capsesc_plist="$HOME/Library/LaunchAgents/dev.dotfiles.capslock-esc.plist"
if [[ -f "$capsesc_plist" ]]; then
  launchctl bootout "gui/$(id -u)" "$capsesc_plist" 2>/dev/null || true
  rm -f "$capsesc_plist"
  hidutil property --matching '{"Built-In":true}' --set '{"UserKeyMapping":[]}' >/dev/null 2>&1 || true
  note 'Removed the old Caps Lock to Esc login item; Kanata handles the built-in keyboard now.'
fi
if [[ -n "${CI:-}" ]]; then
  kanata_apply_config
  # The LaunchDaemons need sudo and a real keyboard, so CI only checks that they render.
  kb_render org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist VHID_ROOT="$vhid_root" >"$kb_tmp/vhid.plist"
  kb_render dev.kanata.kanata.plist KANATA_LABEL="$kanata_label" KANATA_BIN="$kanata_bin" KANATA_CFG="$kanata_cfg" KANATA_LOG="$kanata_log" >"$kb_tmp/kanata.plist"
  kb_render dev.kanata.kanata.plist KANATA_LABEL="$kanata_builtin_label" KANATA_BIN="$kanata_bin" KANATA_CFG="$kanata_builtin_cfg" KANATA_LOG="$kanata_builtin_log" >"$kb_tmp/kanata-builtin.plist"
  run plutil -lint "$kb_tmp/vhid.plist" "$kb_tmp/kanata.plist" "$kb_tmp/kanata-builtin.plist"
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
  # 4. ROG/ASUS keyboards plugged in now join the ROG list, and the built-in keyboard its own
  # list. Only listed keyboards are picked up when plugged in after Kanata starts (see the
  # config). An older install put the built-in keyboard on the ROG list; it moves.
  [[ -f "$kanata_names" ]] || echo '# Keyboards the ROG Kanata grabs, one name per line, as kanata --list prints them.' >"$kanata_names"
  [[ -f "$kanata_builtin_names" ]] || echo "# The Mac's built-in keyboard, as kanata --list prints it; it runs its own Kanata." >"$kanata_builtin_names"
  if grep -qiE '^apple internal keyboard' "$kanata_names"; then
    grep -iE '^apple internal keyboard' "$kanata_names" >>"$kanata_builtin_names" || true
    grep -viE '^apple internal keyboard' "$kanata_names" >"$kb_tmp/names" || true
    cp "$kb_tmp/names" "$kanata_names"
  fi
  kb_list=$({ "$kanata_bin" --list 2>/dev/null || sudo -n "$kanata_bin" --list 2>/dev/null; } | sed -nE 's/^0x[0-9A-Fa-f]+ +[0-9]+ +[0-9]+ +//p' | sed -E 's/[[:space:]]+$//' | sort -u || true)
  kb_add_names() { # names file, then names on stdin
    local name
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      grep -qxF -- "$name" "$1" || { printf '%s\n' "$name" >>"$1"; note "Kanata will grab this keyboard: $name ($(short_path "$1"))"; }
    done
  }
  grep -iE 'rog|asus' <<<"$kb_list" | kb_add_names "$kanata_names" || true
  # If kanata couldn't list keyboards here (no permission yet), macOS's own list names the
  # built-in keyboard the same way, from the same IOKit product name.
  if [[ -z "$kb_list" ]]; then
    kb_list=$(hidutil list 2>/dev/null | grep -oE 'Apple Internal Keyboard( / Trackpad)?' | sort -u || true)
  fi
  grep -iE '^apple internal keyboard' <<<"$kb_list" | kb_add_names "$kanata_builtin_names" || true
  grep -qvE '^(#|$)' "$kanata_names" || detail 'No ROG/ASUS keyboard listed yet, so Kanata grabs every keyboard but the built-in one. Plug it in and rerun to list it.'
  kanata_apply_config
  "$kanata_bin" --check -c "$kanata_cfg" >/dev/null || die "Kanata rejected $kanata_cfg; fix it, then rerun."
  if kanata_has_builtin; then
    "$kanata_bin" --check -c "$kanata_builtin_cfg" >/dev/null || die "Kanata rejected $kanata_builtin_cfg; fix it, then rerun."
  fi
  # 5. kanata itself, as root at boot (it must be root to reach the driver): one daemon per
  # config. The ROG one goes first, so it lets go of the built-in keyboard (an older install
  # grabbed it there) before the built-in one takes it.
  kb_daemon() { # label plist cfg log cfg_changed; sets kanata_last
    local label="$1" plist="$2" cfg="$3" log="$4" cfg_changed="$5" before
    kb_render dev.kanata.kanata.plist KANATA_LABEL="$label" KANATA_BIN="$kanata_bin" KANATA_CFG="$cfg" KANATA_LOG="$log" >"$kb_tmp/$label.plist"
    if ! cmp -s "$kb_tmp/$label.plist" "$plist" || ! kb_loaded "$label"; then
      before=$(kanata_log_lines "$log")
      kb_sudo install -m 644 -o root -g wheel "$kb_tmp/$label.plist" "$plist"
      kb_sudo launchctl bootout system "$plist" 2>/dev/null || true
      kb_sudo launchctl bootstrap system "$plist"
      detail "Kanata LaunchDaemon installed: $plist (log: $log)"
      kb_fresh=true
      kanata_wait_outcome "$before" "$log"
    elif [[ "$cfg_changed" == true || "$kanata_bin_changed" == true ]]; then
      detail "Restarting $label with the new config."
      kanata_restart "$label" "$plist" "$log"
    else
      # Nothing changed. The log's newest start describes Kanata only while it is running; an
      # old success in the log says nothing about a Kanata that has since stopped.
      kanata_last=none
      if kanata_running "$label"; then kanata_last=$(kanata_outcome 0 "$log"); fi
      if [[ "$kanata_last" != ok && "$kanata_last" != waiting && -t 0 ]]; then kanata_restart "$label" "$plist" "$log"; fi
    fi
  }
  kb_daemon "$kanata_label" "$kanata_plist" "$kanata_cfg" "$kanata_log" "$kanata_cfg_changed"
  kanata_state=$kanata_last
  if kanata_has_builtin; then
    kb_daemon "$kanata_builtin_label" "$kanata_builtin_plist" "$kanata_builtin_cfg" "$kanata_builtin_log" "$kanata_builtin_cfg_changed"
    kanata_builtin_state=$kanata_last
  elif [[ -f "$kanata_builtin_plist" ]]; then
    kb_sudo launchctl bootout system "$kanata_builtin_plist" 2>/dev/null || true
    kb_sudo rm -f "$kanata_builtin_plist"
  fi
  kb_settled() { [[ "$1" == ok || "$1" == waiting ]]; }
  # 6. The one-time macOS approvals, one System Settings window at a time.
  if ! kb_settled "$kanata_state" || { [[ -n "$kanata_builtin_state" ]] && ! kb_settled "$kanata_builtin_state"; }; then
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
      kanata_restart_rog
      [[ -z "$kanata_builtin_state" ]] || kanata_restart_builtin
    fi
  fi
  kanata_grabs=$(kanata_grabs)
  if [[ -z "$kanata_grabs" && -n "$kanata_builtin_state" ]]; then kanata_grabs='every keyboard but the built-in one'; fi
  kb_also=''
  [[ "$kanata_builtin_state" != ok ]] || kb_also=', and the built-in keyboard'
  case "$kanata_state" in
    ok) ok "running on ${kanata_grabs:-every keyboard}$kb_also" ;;
    waiting) ok "running$kb_also; plug in ${kanata_grabs:-a keyboard} to start the layer there" ;;
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
  if [[ -n "$kanata_builtin_state" ]] && kb_settled "$kanata_state" && ! kb_settled "$kanata_builtin_state"; then
    warn "The built-in keyboard's Kanata is not running ($kanata_builtin_state); check $kanata_builtin_log." \
      'Rerun bash install.sh in a terminal to try again.'
  fi
  if [[ "$kb_fresh" == true ]]; then
    note 'Hold Left Ctrl + Space + Esc together to quit Kanata if the keyboard ever misbehaves.'
  fi
fi
[[ -z "${kb_sudo_keepalive:-}" ]] || kill "$kb_sudo_keepalive" 2>/dev/null || true
