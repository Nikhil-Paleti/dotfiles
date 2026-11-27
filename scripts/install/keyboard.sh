# Keyboard layer (config/kanata/kanata.kbd): hold left space or Caps Lock for numbers, brackets
# and arrows. Kanata runs it on the machines with the keyboard, the Mac and Windows; Linux
# machines are reached over SSH and need nothing.
#   macOS: Kanata the way its docs set it up (docs/setup-macos.md in jtroo/kanata): the
#     Karabiner VirtualHIDDevice driver, the kanata binary in /usr/local/bin, and two
#     LaunchDaemons (the driver's daemon and kanata) so it starts at boot. Asks for the sudo
#     password at most once per run, only when something is missing or out of date. Then it
#     checks Kanata's log and, if macOS approvals are missing, opens each System Settings
#     window in turn with what to do there. Kanata grabs only the keyboards named in
#     ~/.config/kanata/macos-keyboards.txt (ROG/ASUS ones are added automatically), so one
#     plugged in later is still picked up. Skipped in CI.
#   WSL: the config is copied to Windows, to %APPDATA%\kanata\kanata.kbd, where Windows Kanata
#     finds it without flags. A copy, so Kanata doesn't need WSL running at login.
# Kanata and the driver are pinned as a pair: Kanata 1.12.0 talks to driver 6.2.0 only (newer
# drivers changed the protocol; Kanata 1.13 moves to driver 8). Bump both together.
##### Keyboard layer install #####
block_start "Keyboard layer"
kanata_src="$DOTFILES_ROOT/config/kanata/kanata.kbd"
# shellcheck disable=SC2154 # os is set by scripts/platform.sh
case "$os" in
  Darwin)
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
    # The keyboards Kanata grabs, one name per line (as `kanata --list` prints them). install.sh
    # adds the ROG/ASUS keyboards it finds; edit it to add or drop one. Empty: every keyboard.
    kanata_names="$kanata_dir/macos-keyboards.txt"
    kanata_log=/var/log/kanata.log
    vhid_root='/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice'
    vhid_manager=/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager
    vhid_plist=/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist
    kanata_plist=/Library/LaunchDaemons/dev.kanata.kanata.plist
    # shellcheck disable=SC2154 # _dotfiles_download_dir is set by scripts/lib/temp.sh
    kb_tmp="$_dotfiles_download_dir/keyboard"
    mkdir -p "$kb_tmp" "$kanata_dir"
    verify_sha256() { # file, expected
      [[ "$(shasum -a 256 "$1" | cut -d ' ' -f 1)" == "$2" ]] || { echo "Checksum mismatch for $1; not installing it." >&2; exit 1; }
    }
    # sudo asks for the password once per run: the first root step asks, then a background loop
    # keeps sudo's timestamp fresh until this step ends (or install.sh exits).
    kb_sudo_keepalive=''
    kb_sudo() {
      if [[ -z "$kb_sudo_keepalive" ]]; then
        sudo -v -p 'Password for the keyboard layer (asked once): ' || { echo 'sudo failed; keyboard layer not set up.' >&2; exit 1; }
        ( while kill -0 "$$" 2>/dev/null && sudo -n -v 2>/dev/null; do sleep 30; done ) >/dev/null 2>&1 &
        kb_sudo_keepalive=$!
      fi
      sudo "$@"
    }
    # The repo config, with the keyboard names from $kanata_names in place of its marker line.
    kanata_render() {
      local names='' line
      if [[ -f "$kanata_names" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
          [[ -n "$line" && "$line" != \#* ]] || continue
          if [[ "$line" == *'"'* ]]; then echo "Skipping keyboard name with a quote in $kanata_names: $line" >&2; continue; fi
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
    # The installed config is replaced by the rendered repo config. kanata (a root daemon)
    # reads it from there.
    kanata_cfg_changed=false
    kanata_apply_config() {
      kanata_render >"$kb_tmp/kanata.kbd"
      if ! cmp -s "$kb_tmp/kanata.kbd" "$kanata_cfg"; then
        cp "$kb_tmp/kanata.kbd" "$kanata_cfg"
        kanata_cfg_changed=true
      fi
      echo "Kanata config applied: $kanata_cfg"
    }
    kanata_read_log() { if [[ -r "$kanata_log" ]]; then cat "$kanata_log"; else sudo -n cat "$kanata_log" 2>/dev/null || true; fi; }
    kanata_log_lines() { kanata_read_log | wc -l | tr -d ' '; }
    # How the newest Kanata start after log line $1 went: ok, waiting (none of its keyboards is
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
    # Wait (up to 20 s) for the Kanata start after log line $1 to settle; sets kanata_state.
    # (Not run in $(...): kb_sudo must run in this shell so the password is asked once.)
    kanata_state=none
    kanata_wait_outcome() {
      local _
      for _ in {1..20}; do
        kanata_state=$(kanata_outcome "$1")
        [[ "$kanata_state" == pending || "$kanata_state" == none ]] || break
        sleep 1
      done
    }
    kanata_restart() { # restart Kanata and set kanata_state to how the new start went
      local before
      before=$(kanata_log_lines)
      kb_sudo launchctl kickstart -k system/dev.kanata.kanata
      kanata_wait_outcome "$before"
    }
    # Caps Lock is Esc on the Mac's built-in keyboard too. Kanata leaves that keyboard alone,
    # so macOS's own key remapping (hidutil, Apple TN2450) does it, from a login item, since a
    # hidutil mapping lasts only until restart. Only built-in keyboards; no sudo. It replaces any
    # other key mapping on the built-in keyboard (System Settings > Keyboard > Modifier Keys).
    capsesc_plist="$HOME/Library/LaunchAgents/dev.dotfiles.capslock-esc.plist"
    capsesc_map='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771129,"HIDKeyboardModifierMappingDst":30064771113}]}'
    cat >"$kb_tmp/capsesc.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.dotfiles.capslock-esc</string>
  <key>ProgramArguments</key><array>
    <string>/usr/bin/hidutil</string><string>property</string>
    <string>--matching</string><string>{"Built-In":true}</string>
    <string>--set</string><string>$capsesc_map</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
    if [[ -n "${CI:-}" ]]; then
      echo 'CI: Caps Lock to Esc login item skipped (needs a login session).'
    elif ! cmp -s "$kb_tmp/capsesc.plist" "$capsesc_plist"; then
      mkdir -p "$(dirname "$capsesc_plist")"
      cp "$kb_tmp/capsesc.plist" "$capsesc_plist"
      launchctl bootout "gui/$(id -u)" "$capsesc_plist" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "$capsesc_plist" ||
        hidutil property --matching '{"Built-In":true}' --set "$capsesc_map" >/dev/null
      echo "Caps Lock is Esc on the built-in keyboard (login item: $capsesc_plist)."
    fi
    if [[ -n "${CI:-}" ]]; then
      kanata_apply_config
      echo 'CI: driver, kanata binary and LaunchDaemons skipped (they need sudo and a real keyboard).'
    elif [[ -d /Applications/Karabiner-Elements.app ]]; then
      kanata_apply_config
      echo 'Karabiner-Elements is installed. It ships its own driver and grabs the keyboard, so it' >&2
      echo 'cannot run beside Kanata. Uninstall it (its menu: Uninstall), then rerun; Kanata skipped.' >&2
    else
      kanata_bin_changed=false
      # 1. The driver Kanata sends keys through, from its official signed package.
      vhid_installed=$(pkgutil --pkg-info org.pqrs.Karabiner-DriverKit-VirtualHIDDevice 2>/dev/null | awk '/^version:/ {print $2}' || true)
      if [[ "$vhid_installed" != "$vhid_version" ]]; then
        echo "Installing the Karabiner VirtualHIDDevice driver $vhid_version${vhid_installed:+ (replacing $vhid_installed)}."
        curl -fsSL "https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v$vhid_version/Karabiner-DriverKit-VirtualHIDDevice-$vhid_version.pkg" -o "$kb_tmp/vhid.pkg"
        verify_sha256 "$kb_tmp/vhid.pkg" "$vhid_sha256"
        kb_sudo installer -pkg "$kb_tmp/vhid.pkg" -target /
        kb_sudo "$vhid_manager" forceActivate
      fi
      # 2. The driver's daemon. Karabiner-Elements would run it; without it, a LaunchDaemon does.
      cat >"$kb_tmp/vhid.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>org.pqrs.Karabiner-VirtualHIDDevice-Daemon</string>
  <key>ProgramArguments</key><array><string>$vhid_root/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST
      if ! cmp -s "$kb_tmp/vhid.plist" "$vhid_plist"; then
        kb_sudo install -m 644 -o root -g wheel "$kb_tmp/vhid.plist" "$vhid_plist"
        kb_sudo launchctl bootout system "$vhid_plist" 2>/dev/null || true
        kb_sudo launchctl bootstrap system "$vhid_plist"
        echo "Driver daemon LaunchDaemon installed: $vhid_plist"
      fi
      # 3. The kanata binary from Kanata's release (the build without cmd actions, so the
      # user-writable config can't run commands as root). Root-owned, as the daemon runs it.
      kanata_installed=$("$kanata_bin" --version 2>/dev/null || true)
      if [[ "$kanata_installed" != "kanata $kanata_version" ]]; then
        echo "Installing kanata $kanata_version to $kanata_bin."
        curl -fsSL "https://github.com/jtroo/kanata/releases/download/v$kanata_version/macos-binaries-$kanata_arch.zip" -o "$kb_tmp/kanata.zip"
        verify_sha256 "$kb_tmp/kanata.zip" "$kanata_zip_sha256"
        unzip -p "$kb_tmp/kanata.zip" "kanata_macos_$kanata_arch" >"$kb_tmp/kanata"
        kb_sudo install -d -m 755 -o root -g wheel "$(dirname "$kanata_bin")"
        kb_sudo install -m 755 -o root -g wheel "$kb_tmp/kanata" "$kanata_bin"
        kanata_bin_changed=true
      fi
      # 4. Which keyboards Kanata grabs: ROG/ASUS keyboards plugged in now join the list. Only
      # listed keyboards are picked up when plugged in after Kanata starts (see the config).
      [[ -f "$kanata_names" ]] || echo '# Keyboards Kanata grabs, one name per line, as kanata --list prints them.' >"$kanata_names"
      while IFS= read -r kb_name; do
        [[ -n "$kb_name" ]] || continue
        grep -qxF -- "$kb_name" "$kanata_names" || { printf '%s\n' "$kb_name" >>"$kanata_names"; echo "Kanata will grab this keyboard: $kb_name ($kanata_names)"; }
      done < <({ "$kanata_bin" --list 2>/dev/null || sudo -n "$kanata_bin" --list 2>/dev/null; } | sed -nE 's/^0x[0-9A-Fa-f]+ +[0-9]+ +[0-9]+ +//p' | sed -E 's/[[:space:]]+$//' | grep -iE 'rog|asus' | sort -u || true)
      grep -qvE '^(#|$)' "$kanata_names" || echo "No ROG/ASUS keyboard found, so Kanata grabs every keyboard. Plug it in and rerun to grab only it."
      kanata_apply_config
      "$kanata_bin" --check -c "$kanata_cfg" >/dev/null || { echo "Kanata rejected $kanata_cfg; fix it, then rerun." >&2; exit 1; }
      # 5. kanata itself, as root at boot (it must be root to reach the driver).
      cat >"$kb_tmp/kanata.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.kanata.kanata</string>
  <key>ProgramArguments</key><array><string>$kanata_bin</string><string>-c</string><string>$kanata_cfg</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>StandardOutPath</key><string>$kanata_log</string>
  <key>StandardErrorPath</key><string>$kanata_log</string>
</dict>
</plist>
PLIST
      kanata_before=$(kanata_log_lines)
      if ! cmp -s "$kb_tmp/kanata.plist" "$kanata_plist"; then
        kb_sudo install -m 644 -o root -g wheel "$kb_tmp/kanata.plist" "$kanata_plist"
        kb_sudo launchctl bootout system "$kanata_plist" 2>/dev/null || true
        kb_sudo launchctl bootstrap system "$kanata_plist"
        echo "Kanata LaunchDaemon installed: $kanata_plist (log: $kanata_log)"
        kanata_wait_outcome "$kanata_before"
      elif [[ "$kanata_cfg_changed" == true || "$kanata_bin_changed" == true ]]; then
        echo 'Restarting Kanata with the new config.'
        kanata_restart
      else
        kanata_state=$(kanata_outcome 0)
        if [[ ( "$kanata_state" == none || "$kanata_state" == pending ) && -t 0 ]]; then kanata_restart; fi
      fi
      # 6. The one-time macOS approvals, one System Settings window at a time.
      if [[ "$kanata_state" != ok && "$kanata_state" != waiting ]]; then
        kb_panes=()
        systemextensionsctl list 2>/dev/null | grep -F org.pqrs.Karabiner-DriverKit-VirtualHIDDevice | grep -qF '[activated enabled]' ||
          kb_panes+=(driver)
        kb_panes+=(input-monitoring accessibility)
        if [[ -t 0 && -t 1 ]]; then
          printf '\nKanata needs %s one-time macOS approvals. Each System Settings window opens in turn;\n' "${#kb_panes[@]}"
          echo 'do what is printed here, then come back and press Enter.'
          printf '%s' "$kanata_bin" | pbcopy 2>/dev/null || true
          kb_step=0
          for kb_pane in "${kb_panes[@]}"; do
            kb_step=$((kb_step + 1))
            case "$kb_pane" in
              driver)
                printf '\n%s/%s Driver Extensions (opening Login Items & Extensions)\n' "$kb_step" "${#kb_panes[@]}"
                echo '  Scroll down to Extensions and click the (i) next to Driver Extensions.'
                echo '  Switch on Karabiner-DriverKit-VirtualHIDDevice, enter your password, then click Done.'
                echo '  (macOS 14 and older: Privacy & Security shows "System software ... was blocked"; click Allow.)'
                open 'x-apple.systempreferences:com.apple.LoginItems-Settings.extension' 2>/dev/null || true ;;
              input-monitoring|accessibility)
                if [[ "$kb_pane" == input-monitoring ]]; then kb_title='Input Monitoring' kb_anchor=Privacy_ListenEvent
                else kb_title='Accessibility' kb_anchor=Privacy_Accessibility; fi
                printf '\n%s/%s %s (opening Privacy & Security > %s)\n' "$kb_step" "${#kb_panes[@]}" "$kb_title" "$kb_title"
                echo '  If kanata is in the list, switch it on and you are done here.'
                echo "  If it's missing: click +, press Cmd+Shift+G, paste $kanata_bin (it's on your"
                echo '  clipboard), press Enter, click Open, and switch it on.'
                echo '  If it was already on and Kanata still failed: select it, click -, then add it as above.'
                open "x-apple.systempreferences:com.apple.preference.security?$kb_anchor" 2>/dev/null || true ;;
            esac
            read -r -p '  Press Enter when done. ' _ || true
          done
          echo 'Restarting Kanata to check the approvals.'
          kanata_restart
        else
          echo 'Kanata is not running yet: it needs one-time macOS approvals. Run bash install.sh in a'
          echo 'terminal and it walks you through each System Settings window.'
        fi
      fi
      kanata_grabs=$(grep -vE '^(#|$)' "$kanata_names" | paste -sd ',' - | sed 's/,/, /g' || true)
      case "$kanata_state" in
        ok) echo "Kanata is running on: ${kanata_grabs:-every keyboard}. Hold left space to test the layer." ;;
        waiting) echo "Kanata is running and waits for: $kanata_grabs. Plug the keyboard in and the layer starts." ;;
        input-monitoring) echo 'Kanata still lacks Input Monitoring. Rerun bash install.sh to go through the windows again.' >&2 ;;
        accessibility) echo 'Kanata still lacks Accessibility. Rerun bash install.sh to go through the windows again.' >&2 ;;
        driver) echo 'The Karabiner driver is not switched on yet (Driver Extensions). Rerun bash install.sh.' >&2 ;;
        grab-failed) echo 'Kanata could not grab the keyboard. Remove kanata (-) from Input Monitoring and Accessibility, rerun bash install.sh to add it back.' >&2 ;;
        *) echo "Kanata has not reported in yet; check $kanata_log, then rerun bash install.sh." >&2 ;;
      esac
      echo 'Hold Left Ctrl + Space + Esc together to quit Kanata if the keyboard ever misbehaves.'
    fi
    [[ -z "${kb_sudo_keepalive:-}" ]] || kill "$kb_sudo_keepalive" 2>/dev/null || true
    ;;
  Linux)
    # shellcheck disable=SC2154 # kernel_release is set by scripts/platform.sh on Linux
    case "$kernel_release" in
      *[Mm]icrosoft*)
        cmd_exe=$(command -v cmd.exe || echo /mnt/c/Windows/System32/cmd.exe)
        # Run from cmd.exe's own (Windows) folder: it warns about a WSL working directory.
        win_appdata=$(cd "$(dirname "$cmd_exe")" 2>/dev/null && "$cmd_exe" /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r') ||
          win_appdata=''
        if [[ "$win_appdata" == [A-Za-z]:\\* ]] && win_kanata_dir=$(wslpath -u "$win_appdata\\kanata" 2>/dev/null); then
          mkdir -p "$win_kanata_dir"
          if cmp -s "$kanata_src" "$win_kanata_dir/kanata.kbd"; then
            echo "Windows Kanata config already current: $win_appdata\\kanata\\kanata.kbd"
          else
            cp "$kanata_src" "$win_kanata_dir/kanata.kbd"
            echo "Windows Kanata config applied: $win_appdata\\kanata\\kanata.kbd"
            echo 'If Kanata is running on Windows, pick Reload in its tray icon menu.'
          fi
        else
          echo 'Could not find the Windows user folder from WSL (cmd.exe interop off?); Windows Kanata config not copied.' >&2
          echo "Copy $kanata_src to %APPDATA%\\kanata\\kanata.kbd by hand." >&2
        fi
        ;;
      *) echo 'Linux: skipped. Kanata runs on the Mac or Windows machine with the keyboard.' ;;
    esac
    ;;
esac
block_end "Keyboard layer"
##### end Keyboard layer install #####
