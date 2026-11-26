# Dotfiles

Personal LazyVim configuration and a Bash installer for command-line tools.

## Install or update

On macOS, finish `xcode-select --install` first.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

Use the same command every time. It upgrades installed Homebrew packages from the [tool list](scripts/components.sh), installs missing tools, and applies the repo Neovim config. Existing commands from other package managers are reused, not upgraded or replaced. Homebrew is installed if needed and set up automatically for future bash and zsh sessions. Neovim's Mason `bin` directory is also added to `PATH` in `~/.bashrc` or `~/.zshrc` (after Homebrew, once, without duplicates), so tools reused from Mason, such as `ruff`, work in the terminal too. The installer cannot change the PATH of the terminal that launched it: open a new terminal, or run the exact `eval` command printed at the end. Your default shell is unchanged.

Carbonfox is the default Neovim theme, with a pure black background for OLED screens and more saturated accent colors (tune `pop` in `lua/plugins/carbonfox.lua`). The start screen (`nvim` or `nvim .`) shows the folder's recent files and the repo status with its jj bookmark or git branch; the file explorer opens with `Space e`. Open `nvim` to install editor plugins, then run `:LazyHealth` and `:checkhealth mason`.

Neovim has Python, markdown, and Bazel support (`BUILD`, `.bzl`, and `.bazelrc` files). Nothing is formatted on save; format the current file with `Space c f`. On Linux, the installer adds ICU (`libicuN`), which the markdown language server needs. Yanks use the OSC 52 clipboard, so they reach the clipboard of whatever terminal you view Neovim in, including over SSH.

The shell gets [Atuin](https://atuin.sh/) for searchable history: `Ctrl+R` searches everything full screen (press `Ctrl+R` again to narrow to this machine, session, folder, or repo), and `Up` searches this terminal's history in a small panel. It is local only: no account, no sync, no update check. Its settings live in [config/atuin/config.toml](config/atuin/config.toml). On bash, [ble.sh](https://github.com/akinomyoga/ble.sh) adds fish-style suggestions as you type (accept with `→`), syntax highlighting, and a `Tab` completion menu; On zsh, Homebrew's `zsh-autosuggestions` (fed by Atuin) and `zsh-syntax-highlighting` do the same, with zsh's `Tab` menu turned on. The prompt is [Starship](https://starship.rs/), configured in [config/starship/starship.toml](config/starship/starship.toml); in jj repos it shows the working-copy change and nearest bookmark instead of git's detached commit. The installer appends their startup lines to `~/.bashrc` or `~/.zshrc` only when missing and never changes anything else there. Run `atuin import auto` once on a new machine to bring in existing shell history.

Ideas not set up yet are listed in [canexplore.md](canexplore.md).

For Octo, run `gh auth status` and, if needed, `gh auth login` once. Then use `:Octo pr list` and `:checkhealth octo` in Neovim.

On WSL, the current-terminal command is normally:

```sh
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

For icon glyphs, [LazyVim needs a Nerd Font v3+](https://www.lazyvim.org/). With Windows Terminal, install the font on Windows and select it for the Ubuntu/WSL profile under [Settings → Appearance → Font face](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance#font-face). The Linux installer does not configure the Windows terminal font.

## Run again

From the repo checkout on `main`:

```sh
git pull --ff-only
bash install.sh
```

There are no separate install/update modes. Each run updates managed packages, installs missing tools, and refreshes the config. Restart Neovim so Lazy can install newly added plugins, including Nightfox for Carbonfox.

## Configuration ownership

Every run replaces `${XDG_CONFIG_HOME:-$HOME/.config}/nvim` without backups. Local-only edits and extra files in the Neovim config directory are removed. GitHub preserves committed repo versions, **not changes made only to the installed copies**; save anything you want to keep before running the installer. Keep shared customizations in the repo.

Existing config symlinks are replaced, not followed; their external targets and any old backup directories are left untouched. Run one installer at a time. Configs are staged before replacement, but replacement is not an atomic transaction: if it fails after removal, correct the reported error and rerun. No rollback copy is retained.
