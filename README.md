# Dotfiles

Personal LazyVim and tmux configuration and a Bash installer for command-line tools, including TUIOS.

## Install or update

On macOS, finish `xcode-select --install` first.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

Use the same command every time. It upgrades installed Homebrew packages from the [tool list](scripts/components.sh), installs missing tools, and applies the repo Neovim and tmux configs. Existing commands from other package managers are reused, not upgraded or replaced. Homebrew is installed if needed and set up automatically for future bash and zsh sessions. The installer cannot change the PATH of the terminal that launched it: open a new terminal, or run the exact `eval` command printed at the end. Your default shell is unchanged.

[TUIOS](https://tuios.dev/docs/getting-started) is installed and updated through the Homebrew core `tuios` formula on macOS and Linux, including ARM64. Run `tuios` to launch it. It keeps its own defaults and any existing user config; the installer does not auto-start it or change your shell. TUIOS uses Ctrl+B as its default prefix. tmux remains available alongside it.

tmux uses the repo [config](config/tmux/tmux.conf) at `~/.tmux.conf`: Ctrl+A prefix, mouse support, numbering from 1, Vim-style pane navigation/resizing, and Prefix+r to reload. Any XDG tmux config is left untouched; `~/.tmux.conf` takes precedence. Existing servers keep their current settings until you explicitly load the new config.

Carbonfox is the default Neovim theme. Open `nvim` to install editor plugins, then run `:LazyHealth` and `:checkhealth mason`.

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

There are no separate install/update modes. Each run updates managed packages, installs missing tools, and refreshes the configs. Restart Neovim so Lazy can install newly added plugins, including Nightfox for Carbonfox. Existing tmux servers need `tmux source-file ~/.tmux.conf` to reload.

## Configuration ownership

Every run replaces `${XDG_CONFIG_HOME:-$HOME/.config}/nvim` and `~/.tmux.conf` without backups. Local-only edits and extra files in the Neovim config directory are removed. GitHub preserves committed repo versions, **not changes made only to the installed copies**; save anything you want to keep before running the installer. Keep shared customizations in the repo.

Existing config symlinks are replaced, not followed; their external targets and any old backup directories are left untouched. XDG tmux files and custom `tmux -f` paths remain user-managed. Run one installer at a time. Configs are staged before replacement, but replacement is not an atomic transaction: if it fails after removal, correct the reported error and rerun. No rollback copy is retained.
