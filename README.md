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

From the repo directory:

```sh
bash install.sh --update
```

Upgrades installed Homebrew packages from the [tool list](scripts/components.sh); it doesn't install missing tools or replace config. Manage Neovim plugins with `:Lazy update` and Mason packages inside Neovim. Use `bash install.sh --help` for usage.

### Apply the theme to an existing installation

The installer copies Neovim config; pulling the repo or running `--update` does not change that installed copy. To apply only Carbonfox, from your dotfiles checkout on `main`:

```sh
git pull --ff-only
nvim_config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
mkdir -p "$nvim_config/lua/plugins"
cp -i config/nvim/lua/plugins/carbonfox.lua "$nvim_config/lua/plugins/carbonfox.lua"
```

If that file already exists, save your edits before confirming replacement. Restart Neovim and let Lazy install Nightfox (or run `:Lazy install`), then restart again. Check `:echo g:colors_name` prints `carbonfox`. This leaves other config files and plugin pins alone; the new plugin gets its own local lock entry. Any other colorscheme override in your config must also be removed or changed.

For the complete repo configuration instead, rerun `bash install.sh --install`: installed tools are reused, and your Neovim/tmux configs are backed up before replacement.

## Backups and restore

Backups stay beside `nvim`, named `nvim_backup`, then `nvim_backup.1`, `nvim_backup.2`, etc. The installer prints the actual path and never deletes backups automatically.

tmux backups stay beside `~/.tmux.conf`, named `.tmux.conf_backup`, then `.tmux.conf_backup.1`, etc. Symlinks are backed up as symlinks; their targets are not edited. To restore, move the current `.tmux.conf` aside and rename the chosen backup to `.tmux.conf`. Custom `tmux -f` startup paths are not changed.

To restore, close Neovim, move the current `nvim` path aside to an unused name, then rename your chosen backup to `nvim`. Run only one installer at a time; if replacement fails, follow its recovery message.
