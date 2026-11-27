# Keyboard layer (config/kanata/kanata.kbd): hold left space or Caps Lock for numbers, brackets
# and arrows. Kanata runs it on the machines with the keyboard, the Mac and Windows; Linux
# machines are reached over SSH and need nothing.
#   macOS: Kanata the way its docs set it up (docs/setup-macos.md in jtroo/kanata): the
#     Karabiner VirtualHIDDevice driver, the kanata binary in /usr/local/bin, and two
#     LaunchDaemons (the driver's daemon and kanata) so it starts at boot. Needs sudo, and only
#     asks for it when something is missing or out of date. Skipped in CI.
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
    kanata_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/kanata/kanata.kbd"
    vhid_root='/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice'
    vhid_manager=/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager
    vhid_plist=/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist
    kanata_plist=/Library/LaunchDaemons/dev.kanata.kanata.plist
    # shellcheck disable=SC2154 # _dotfiles_download_dir is set by scripts/lib/temp.sh
    kb_tmp="$_dotfiles_download_dir/keyboard"
    mkdir -p "$kb_tmp" "$(dirname "$kanata_cfg")"
    verify_sha256() { # file, expected
      [[ "$(shasum -a 256 "$1" | cut -d ' ' -f 1)" == "$2" ]] || { echo "Checksum mismatch for $1; not installing it." >&2; exit 1; }
    }
    # The repo config replaces the installed one. kanata (a root daemon) reads it from there.
    kanata_cfg_changed=false
    if ! cmp -s "$kanata_src" "$kanata_cfg"; then
      cp "$kanata_src" "$kanata_cfg"
      kanata_cfg_changed=true
    fi
    echo "Kanata config applied: $kanata_cfg"
    if [[ -n "${CI:-}" ]]; then
      echo 'CI: driver, kanata binary and LaunchDaemons skipped (they need sudo and a real keyboard).'
    elif [[ -d /Applications/Karabiner-Elements.app ]]; then
      echo 'Karabiner-Elements is installed. It ships its own driver and grabs the keyboard, so it' >&2
      echo 'cannot run beside Kanata. Uninstall it (its menu: Uninstall), then rerun; Kanata skipped.' >&2
    else
      fresh_setup=false
      # 1. The driver Kanata sends keys through, from its official signed package.
      vhid_installed=$(pkgutil --pkg-info org.pqrs.Karabiner-DriverKit-VirtualHIDDevice 2>/dev/null | awk '/^version:/ {print $2}' || true)
      if [[ "$vhid_installed" != "$vhid_version" ]]; then
        echo "Installing the Karabiner VirtualHIDDevice driver $vhid_version${vhid_installed:+ (replacing $vhid_installed)}; sudo asks for your password."
        curl -fsSL "https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v$vhid_version/Karabiner-DriverKit-VirtualHIDDevice-$vhid_version.pkg" -o "$kb_tmp/vhid.pkg"
        verify_sha256 "$kb_tmp/vhid.pkg" "$vhid_sha256"
        sudo installer -pkg "$kb_tmp/vhid.pkg" -target /
        sudo "$vhid_manager" forceActivate
        fresh_setup=true
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
        sudo install -m 644 -o root -g wheel "$kb_tmp/vhid.plist" "$vhid_plist"
        sudo launchctl bootout system "$vhid_plist" 2>/dev/null || true
        sudo launchctl bootstrap system "$vhid_plist"
        echo "Driver daemon LaunchDaemon installed: $vhid_plist"
      fi
      # 3. The kanata binary from Kanata's release (the build without cmd actions, so the
      # user-writable config can't run commands as root). Root-owned, as the daemon runs it.
      kanata_installed=$("$kanata_bin" --version 2>/dev/null || true)
      kanata_bin_changed=false
      if [[ "$kanata_installed" != "kanata $kanata_version" ]]; then
        echo "Installing kanata $kanata_version to $kanata_bin; sudo asks for your password."
        curl -fsSL "https://github.com/jtroo/kanata/releases/download/v$kanata_version/macos-binaries-$kanata_arch.zip" -o "$kb_tmp/kanata.zip"
        verify_sha256 "$kb_tmp/kanata.zip" "$kanata_zip_sha256"
        unzip -p "$kb_tmp/kanata.zip" "kanata_macos_$kanata_arch" >"$kb_tmp/kanata"
        sudo install -d -m 755 -o root -g wheel "$(dirname "$kanata_bin")"
        sudo install -m 755 -o root -g wheel "$kb_tmp/kanata" "$kanata_bin"
        kanata_bin_changed=true
        fresh_setup=true
      fi
      "$kanata_bin" --check -c "$kanata_cfg" >/dev/null || { echo "Kanata rejected $kanata_cfg; fix it, then rerun." >&2; exit 1; }
      # 4. kanata itself, as root at boot (it must be root to reach the driver).
      cat >"$kb_tmp/kanata.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.kanata.kanata</string>
  <key>ProgramArguments</key><array><string>$kanata_bin</string><string>-c</string><string>$kanata_cfg</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>StandardOutPath</key><string>/var/log/kanata.log</string>
  <key>StandardErrorPath</key><string>/var/log/kanata.log</string>
</dict>
</plist>
PLIST
      if ! cmp -s "$kb_tmp/kanata.plist" "$kanata_plist"; then
        sudo install -m 644 -o root -g wheel "$kb_tmp/kanata.plist" "$kanata_plist"
        sudo launchctl bootout system "$kanata_plist" 2>/dev/null || true
        sudo launchctl bootstrap system "$kanata_plist"
        echo "Kanata LaunchDaemon installed: $kanata_plist (log: /var/log/kanata.log)"
      elif [[ "$kanata_cfg_changed" == true || "$kanata_bin_changed" == true ]]; then
        sudo launchctl kickstart -k system/dev.kanata.kanata
        echo 'Kanata restarted with the new config.'
      else
        echo "kanata $kanata_version, driver $vhid_version and both LaunchDaemons already set up."
      fi
      if [[ "$fresh_setup" == true ]]; then
        "$kanata_bin" --macos-request-permissions >/dev/null 2>&1 || true
        echo 'One-time macOS approvals (System Settings), then: sudo launchctl kickstart -k system/dev.kanata.kanata'
        echo '  1. General > Login Items & Extensions > Driver Extensions: turn on Karabiner-DriverKit-VirtualHIDDevice.'
        echo "  2. Privacy & Security > Input Monitoring and > Accessibility: add $kanata_bin (+, then Cmd+Shift+G)."
        echo 'Hold Left Ctrl + Space + Esc together to quit Kanata if the keyboard ever misbehaves.'
      fi
    fi
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
