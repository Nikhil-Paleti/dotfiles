# Keyboard layer

Hold the left half of the spacebar, or Caps Lock, for numbers, brackets and
arrows on the home row. Tap left space for Space and Caps Lock for Esc. Every
other key is unchanged.

```text
q w e r t   y u i o p   ->   1 2 3 4 5   6 7 8 9 0
a s d f g   h j k l ;   ->   { ( [ < =   Left Down Up Right :
z x c v b   n m , . /   ->   } ) ] > +   _ - & | \
```

- Shift passes through: Shift + layer + `q` gives `!`, and Shift + arrows
  selects.
- A Space typed right after a letter is always a plain Space, so fast typing
  doesn't open the layer.
- [Kanata](https://github.com/jtroo/kanata) runs one config,
  [kanata.kbd](kanata.kbd), on the Mac and Windows. Timings are at the top.
  Linux machines you SSH into need nothing.
- The left half of the split spacebar must send Scroll Lock. Set that in
  Armoury Crate and save it to the keyboard's onboard profile, so the Mac sees
  it too. To use another key, change `slck` on the first line of `defsrc`.
- On Windows the layer works on any keyboard. On the Mac it works on every
  keyboard, and Alt and Command are swapped on all but the built-in one. The
  built-in keyboard has one spacebar, so there only Caps Lock opens the layer;
  Space, Option and Command are unchanged.

## Mac

1. Plug the keyboard in and run `bash install.sh` in a terminal. It asks for
   your password once and installs the Karabiner driver 6.2.0, `kanata` 1.12.0
   and the LaunchDaemons that start them at boot.
2. When it opens a System Settings window, do what the terminal says, then
   press Enter. There are up to three: Driver Extensions, Input Monitoring and
   Accessibility.
3. It restarts Kanata and says whether it works. If not, run it again.

- Kanata grabs every keyboard plugged in when it starts, and grabs them again
  after a replug. A keyboard it hasn't seen needs `dot kb stop`, then
  `dot kb start`.
- `dot kb stop` gives plain Caps Lock back on every keyboard.
- Skipped if Karabiner-Elements is installed, since the two can't run together.
- Setup follows
  [Kanata's macOS guide](https://github.com/jtroo/kanata/blob/v1.12.0/docs/setup-macos.md).

## Windows

1. In WSL, run `bash install.sh`. It copies the config to
   `%APPDATA%\kanata\kanata.kbd`, so Kanata doesn't need WSL running.
2. In PowerShell, run `winget install jtroo.kanata_gui`.
3. In a new PowerShell window, run this once. It starts Kanata now and at
   every login, as a tray icon:

<!-- markdownlint-disable MD013 -->
```powershell
$kanata = (Get-Command kanata_windows_gui_winIOv2_x64.exe).Source
$link = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Kanata.lnk")
$link.TargetPath = $kanata; $link.Arguments = "--cfg `"$env:APPDATA\kanata\kanata.kbd`""; $link.Save()
Start-Process $kanata -ArgumentList "--cfg", "`"$env:APPDATA\kanata\kanata.kbd`""
```
<!-- markdownlint-enable MD013 -->

After `install.sh` changes the config, pick Reload in the tray menu.

## When it misbehaves

- **Check, stop or start it:** `dot kb status`, `dot kb stop`, `dot kb start`
  (Mac, or WSL for Windows).
- **Quit Kanata:** hold Left Ctrl + Space + Esc.
- **Mac log:** `/var/log/kanata.log`.
- **Stopped on Windows:** double-click Kanata in the Startup folder (Win+R,
  then `shell:startup`).
- **An app on Windows doesn't see it:** apps running as administrator only see
  the layer if Kanata also runs as administrator.
