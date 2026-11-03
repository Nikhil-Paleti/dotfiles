# Dotfiles

Personal LazyVim and tmux configuration and a Bash installer for command-line tools.

## Install

On macOS, finish `xcode-select --install` first.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh --install
```

Missing tools use Homebrew, installed if needed; existing commands are reused. Homebrew is set up automatically for future bash and zsh sessions. The installer cannot change the PATH of the terminal that launched it: open a new terminal, or run the exact `eval` command printed at the end. Your default shell is unchanged.

tmux uses the repo [config](config/tmux/tmux.conf) at `~/.tmux.conf`: Ctrl+A prefix, mouse support, numbering from 1, Vim-style pane navigation/resizing, and Prefix+r to reload. Any XDG tmux config is left untouched; `~/.tmux.conf` takes precedence. Existing servers keep their current settings until you explicitly load the new config.

Carbonfox is the default Neovim theme. Open `nvim` to install editor plugins, then run `:LazyHealth` and `:checkhealth mason`.

On WSL, the current-terminal command is normally:

```sh
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

For icon glyphs, [LazyVim needs a Nerd Font v3+](https://www.lazyvim.org/). With Windows Terminal, install the font on Windows and select it for the Ubuntu/WSL profile under [Settings → Appearance → Font face](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance#font-face). The Linux installer does not configure the Windows terminal font.

## Update

From the repo checkout on `main`:

```sh
git pull --ff-only
bash install.sh --update
```

Upgrades installed Homebrew packages from the [tool list](scripts/components.sh), then replaces the installed Neovim and tmux configs with the versions in this checkout. Missing system tools are not installed. Restart Neovim so Lazy can install newly added plugins, including Nightfox for Carbonfox. Existing tmux servers need `tmux source-file ~/.tmux.conf` to reload.

## Configuration ownership

Both `--install` and `--update` replace `${XDG_CONFIG_HOME:-$HOME/.config}/nvim` and `~/.tmux.conf` without backups. Local-only edits and extra files in the Neovim config directory are removed. GitHub preserves committed repo versions, **not changes made only to the installed copies**; save anything you want to keep before running either command. Keep shared customizations in the repo.

Existing config symlinks are replaced, not followed; their external targets and any old backup directories are left untouched. XDG tmux files and custom `tmux -f` paths remain user-managed. Run one installer at a time. Configs are staged before replacement, but replacement is not an atomic transaction: if it fails after removal, correct the reported error and rerun. No rollback copy is retained.
