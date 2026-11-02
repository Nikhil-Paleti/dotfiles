# Dotfiles

Personal LazyVim and tmux configuration and a Bash installer for command-line tools.

## Install

On macOS, finish `xcode-select --install` first.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh --install
```

Missing tools use Homebrew, installed if needed; existing commands are reused. Homebrew is set up automatically for future bash and zsh sessions; open a new terminal after installation. Your default shell is unchanged.

tmux uses the repo [config](config/tmux/tmux.conf) at `~/.tmux.conf`: Ctrl+A prefix, mouse support, numbering from 1, Vim-style pane navigation/resizing, and Prefix+r to reload. Any XDG tmux config is left untouched; `~/.tmux.conf` takes precedence. Existing servers keep their current settings until you explicitly load the new config.

Open `nvim` to install editor plugins, then run `:LazyHealth` and `:checkhealth mason`.

## Update

From the repo directory:

```sh
bash install.sh --update
```

Upgrades installed Homebrew packages from the [tool list](scripts/components.sh); it doesn't install missing tools or replace config. Manage Neovim plugins with `:Lazy update` and Mason packages inside Neovim. Use `bash install.sh --help` for usage.

## Backups and restore

Backups stay beside `nvim`, named `nvim_backup`, then `nvim_backup.1`, `nvim_backup.2`, etc. The installer prints the actual path and never deletes backups automatically.

tmux backups stay beside `~/.tmux.conf`, named `.tmux.conf_backup`, then `.tmux.conf_backup.1`, etc. Symlinks are backed up as symlinks; their targets are not edited. To restore, move the current `.tmux.conf` aside and rename the chosen backup to `.tmux.conf`. Custom `tmux -f` startup paths are not changed.

To restore, close Neovim, move the current `nvim` path aside to an unused name, then rename your chosen backup to `nvim`. Run only one installer at a time; if replacement fails, follow its recovery message.
