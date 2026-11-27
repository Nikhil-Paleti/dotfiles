# Dotfiles

LazyVim config, shell tools and a keyboard layer, set up by one Bash installer.

Works on macOS and Debian/Ubuntu Linux, including WSL2 (ARM64 and x86_64).
Not on native Windows or WSL1.

## Quick start

On macOS, run `xcode-select --install` and let it finish first.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

Then:

1. Open a new terminal, or run the `eval` command the installer prints.
2. Run `nvim` to install the editor plugins.
3. In Neovim, run `:LazyHealth` and `:checkhealth mason`.
4. On a new machine, run `atuin import auto` to bring in your shell history.

> [!WARNING]
> Every run replaces `~/.config/nvim` with no backup. Keep your Neovim
> changes in this repo, not in the installed copy.

## Update

Run the same installer again. There is no separate update mode.

```sh
cd ~/dotfiles
git pull --ff-only
bash install.sh
```

Restart Neovim afterwards so Lazy installs any new plugins.

## What gets installed

| Part           | macOS              | Linux            | WSL2               |
| -------------- | ------------------ | ---------------- | ------------------ |
| Packages       | Homebrew           | Homebrew         | Homebrew           |
| System deps    | Xcode CLT, by you  | apt, with sudo   | apt, with sudo     |
| Keyboard layer | Kanata and driver  | skipped          | copies the config  |

On every platform:

| Group      | Tools                                                        |
| ---------- | ------------------------------------------------------------ |
| Core       | git, jj, gh, curl, bazelisk                                  |
| Editor     | Neovim (LazyVim), tree-sitter CLI                            |
| Search     | ripgrep, fd, fzf, lazygit, [scout][scout]                    |
| Shell      | Atuin, Starship, zoxide                                      |
| bash only  | ble.sh                                                       |
| zsh only   | zsh-autosuggestions, zsh-syntax-highlighting                 |
| Languages  | Python, uv, Node.js, npm, Rust via [rustup][rustup]          |
| Formatters | StyLua, shfmt, ShellCheck, Ruff                              |

The Homebrew tool list is [scripts/components.sh](scripts/components.sh).
bash or zsh extras follow your login shell.

### What the installer changes

- Installs missing tools and upgrades the Homebrew ones. A command already
  installed another way is reused, not upgraded or replaced.
- Installs Homebrew if needed and sets it up for bash and zsh.
- Installs Rust with rustup (per user, no sudo): stable, with `rustfmt`,
  `clippy` and `rust-analyzer`. Each run runs `rustup update`.
- On Linux, adds the apt build tools and ICU (the markdown language server
  needs it). sudo is asked for only when something is missing.
- Adds startup lines to `~/.bashrc` or `~/.zshrc` only when they're missing,
  and changes nothing else there.
  - Mason's `bin` folder goes on `PATH` after Homebrew, so tools like `ruff`
    work in the terminal.
  - Cargo's `bin` folder goes first on `PATH`, unless a startup file already
    loads `~/.cargo/env`.
  - `EDITOR` and `VISUAL` become `nvim`, unless `EDITOR` is already set.
  - Lines are added at the end, except zoxide's, which goes above the ble.sh
    or syntax-highlighting line that has to stay last.
- On zsh, removes group write access from Homebrew's `share` folder, which
  zsh's completion otherwise flags as insecure.
- Leaves your default shell alone.

## Neovim

- **Theme:** Carbonfox on pure black for OLED screens. Tune the accent
  colors with `pop` in `lua/plugins/carbonfox.lua`.
- **Start screen:** `nvim` or `nvim .` shows a random pixel-art scene, the
  folder's recent files and the repo status. Scenes are mountains, aurora,
  desert, city, lighthouse, rain, village and space. Set
  `vim.g.dashboard_scene` to always show one.
- **Languages:** Python, Rust, markdown and Bazel (`BUILD`, `.bzl`,
  `.bazelrc`). Rust uses [rustaceanvim][rustaceanvim] with rustup's
  `rust-analyzer`, and [crates.nvim][crates] in `Cargo.toml`.
- **Formatting:** nothing formats on save. Use `Space c f`.
- **Status bar:** shows the jj bookmark and change, or the git branch and
  commit.
- **Clipboard:** yanks go to your terminal's clipboard over OSC 52, also over
  SSH. To paste from the system clipboard, use the terminal's paste key
  (Cmd+V on the Mac).
- **File explorer:** `Space e` opens it as a popup with a preview. It closes
  when you open a file, and folder names stay pinned at the top while you
  scroll through them.

### Code search with scout

[scout][scout] is an indexed regex search for big repos.

- Opening Neovim in a git repo indexes it in the background, and so does
  `:cd` into another repo. `$HOME` and folders outside git are skipped.
- Once a repo is indexed, LazyVim's search and find-file keys use scout.
  Before that, they use the Snacks picker.
- Queries use Google Code Search syntax: `file:`, `lang:`, `OR`, `-term`.
  `scout --help` lists them all.
- Callers are matched by name, so same-named functions mix.
- `scout` also works in the terminal.
- Indexes live in `~/.cache/scout`, on this machine only.

The installer keeps scout's `main` branch in `modules/scout` (git-ignored, so
deleting this repo deletes it), pulls it every run and builds it with
`cargo install`. Neovim loads the plugin from the same folder, so the plugin
and binary always match. `:Lazy update` doesn't touch scout.

### GitHub in Neovim (Octo)

Run `gh auth status` once, and `gh auth login` if needed. Then use
`:Octo pr list` and `:checkhealth octo`.

## Shell

- **History:** [Atuin][atuin], local only: no account, no sync, no update
  check. Settings are in [config/atuin/config.toml](config/atuin/config.toml).
- **Agent history:** if Claude Code or Codex is installed and Atuin is 18.25
  or newer, Atuin also records the commands they run. They're hidden from
  your searches; `atuin search --author '$all-agent'` shows them.
- **Suggestions and highlighting:** [ble.sh][blesh] on bash.
  `zsh-autosuggestions` (fed by Atuin) and `zsh-syntax-highlighting` on zsh,
  with zsh's `Tab` menu on.
- **Folders:** [zoxide][zoxide] learns the folders you visit. `cd` is
  unchanged.
- **Prompt:** [Starship][starship], set up in
  [config/starship/starship.toml](config/starship/starship.toml). In jj repos
  it shows the change and nearest bookmark.
- **Editor:** `jj describe`, `git commit` and `gh` open Neovim.

## Keyboard layer

Hold the left half of the spacebar, or Caps Lock, for numbers, brackets and
arrows on the home row. Tap left space for Space and Caps Lock for Esc. On
Windows this works on any keyboard. On the Mac the layer is only on the ROG
keyboard, where Alt and Command are also swapped; on the built-in keyboard,
Caps Lock is just Esc. Every other key is unchanged.

```text
q w e r t   y u i o p   ->   1 2 3 4 5   6 7 8 9 0
a s d f g   h j k l ;   ->   { ( [ < =   Left Down Up Right :
z x c v b   n m , . /   ->   } ) ] > +   _ - & | \
```

- Shift passes through: Shift + layer + `q` gives `!`, and Shift + arrows
  selects.
- A Space typed right after a letter is always a plain Space, so fast typing
  doesn't open the layer.
- [Kanata][kanata] runs one config,
  [config/kanata/kanata.kbd](config/kanata/kanata.kbd), on the Mac and
  Windows. Timings are at the top of that file. Linux machines you SSH into
  need nothing.
- The left half of the split spacebar must send Scroll Lock. Set that in
  Armoury Crate and save it to the keyboard's onboard profile, so the Mac
  sees it too. To use another key, change `slck` on the first line of
  `defsrc`.

### Mac setup

1. Plug the keyboard in, then run `bash install.sh` in a terminal. It asks
   for your password once, and installs the Karabiner VirtualHIDDevice driver
   6.2.0, `kanata` 1.12.0 in `/usr/local/bin`, and LaunchDaemons that start
   both at boot.
2. When it opens a System Settings window, do what the terminal says there,
   then press Enter. There are up to three:
   - Driver Extensions: switch on Karabiner-DriverKit-VirtualHIDDevice.
   - Input Monitoring: add `/usr/local/bin/kanata` (+, then Cmd+Shift+G) and
     switch it on.
   - Accessibility: the same.
3. The installer restarts Kanata and says whether it's working. If not, run
   `bash install.sh` again.

- Kanata grabs only the keyboards in `~/.config/kanata/macos-keyboards.txt`.
  The installer adds the ROG/ASUS keyboards it sees. A listed keyboard
  plugged in later, or replugged, is picked up.
- Alt and Command are swapped in Kanata, so the key next to the spacebar is
  Command. macOS's own swap doesn't reach a keyboard Kanata grabs.
- On the built-in keyboard, Caps Lock is Esc through macOS's own remapping
  (`hidutil`, run at login by `~/Library/LaunchAgents/dev.dotfiles.capslock-esc.plist`).
  It replaces any Modifier Keys setting on that keyboard.
- The log is `/var/log/kanata.log`. Left Ctrl + Space + Esc quits Kanata.

The setup follows [Kanata's macOS guide][kanata-mac]. It's skipped if
Karabiner-Elements is installed, since the two can't run together.

### Windows setup

1. In WSL, run `bash install.sh`. It copies the config to
   `%APPDATA%\kanata\kanata.kbd`, so Kanata doesn't need WSL running.
2. In PowerShell, run `winget install jtroo.kanata_gui`.
3. Open a new PowerShell window, since winget's `PATH` change only reaches
   new shells.
4. Run this once. It starts Kanata now and at every login, as a tray icon:

<!-- markdownlint-disable MD013 -->
```powershell
$kanata = (Get-Command kanata_windows_gui_winIOv2_x64.exe).Source
$link = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Kanata.lnk")
$link.TargetPath = $kanata; $link.Arguments = "--cfg `"$env:APPDATA\kanata\kanata.kbd`""; $link.Save()
Start-Process $kanata -ArgumentList "--cfg", "`"$env:APPDATA\kanata\kanata.kbd`""
```
<!-- markdownlint-enable MD013 -->

You can close PowerShell once Kanata is running.

## Troubleshooting

- **A new command isn't found.** The installer can't change the terminal that
  started it. Open a new one, or run the printed `eval` line. On WSL it's
  usually `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"`.
- **Icons show as boxes.** LazyVim needs a [Nerd Font v3+][lazyvim]. On
  Windows Terminal, install the font on Windows and pick it for the
  Ubuntu/WSL profile under
  [Settings > Appearance > Font face][wt-font]. The installer doesn't set it.
- **My Neovim edits are gone.** Each run replaces the config folder and
  removes local-only files. Symlinks there are replaced, not followed; their
  targets and old backups are left alone. Keep changes in this repo.
- **The installer failed halfway.** Fix the reported error and rerun. Run one
  installer at a time; there's no rollback copy.
- **Rust isn't from rustup.** A Rust that rustup doesn't manage, like
  Homebrew's `rust`, is reused, since rustup won't install beside it.
  Uninstall it and rerun to switch.
- **scout is old or missing.** Rerun `bash install.sh`. `:checkhealth scout`
  shows the binary and index state.
- **The status bar branch is stale.** Run `:BranchRefresh`. It refreshes on
  its own after a save, a `:!` command, closing a terminal like lazygit, a
  folder change or focus. The list is at the top of `lua/repo_head.lua`.
- **The keyboard layer stopped on Windows.** Double-click Kanata in the
  Startup folder (Win+R, then `shell:startup`). After `install.sh` changes
  the config, pick Reload in the tray menu.
- **The layer doesn't reach an app on Windows.** Apps running as
  administrator only see it if Kanata also runs as administrator.
- **The layer misbehaves on the Mac.** The log is `/var/log/kanata.log`.
  Hold Left Ctrl + Space + Esc to quit Kanata.

## Later

Ideas not set up yet are in [canexplore.md](canexplore.md).

[atuin]: https://atuin.sh/
[blesh]: https://github.com/akinomyoga/ble.sh
[crates]: https://github.com/Saecki/crates.nvim
[kanata]: https://github.com/jtroo/kanata
[kanata-mac]: https://github.com/jtroo/kanata/blob/v1.12.0/docs/setup-macos.md
[lazyvim]: https://www.lazyvim.org/
[rustaceanvim]: https://github.com/mrcjkb/rustaceanvim
[rustup]: https://rustup.rs/
[scout]: https://github.com/Nikhil-Paleti/scout
[starship]: https://starship.rs/
[wt-font]: https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance#font-face
[zoxide]: https://github.com/ajeetdsouza/zoxide
