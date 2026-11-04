# Dotfiles

Personal LazyVim, tmux, and zsh configuration and a Bash installer for command-line tools.

## Install or update

On macOS, finish `xcode-select --install` first.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

Use the same command every time. It upgrades installed Homebrew packages from the [tool list](scripts/components.sh), installs missing tools and zsh plugins, applies the repo configs, and makes zsh your default login shell if it is not already. Existing commands from other package managers are reused, not upgraded or replaced. Homebrew is installed if needed and set up for future bash and zsh sessions. The installer cannot change the PATH of the terminal that launched it: open a new terminal, or run the exact `eval` command printed at the end.

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

There are no separate install/update modes. Each run refreshes the managed configs and ensures zsh is the default again, including if you switched back to Bash. The managed zsh config is refreshed without replacing your `.zshrc`. Restart Neovim so Lazy can install newly added plugins, including Nightfox for Carbonfox. Existing tmux servers need `tmux source-file ~/.tmux.conf` to reload.

## Configuration ownership

Every run replaces `${XDG_CONFIG_HOME:-$HOME/.config}/nvim` and `~/.tmux.conf` without backups. Local-only edits and extra files in the Neovim config directory are removed. GitHub preserves committed repo versions, **not changes made only to the installed copies**; save anything you want to keep before running the installer. Keep shared customizations in the repo.

Existing config symlinks are replaced, not followed; their external targets and any old backup directories are left untouched. XDG tmux files and custom `tmux -f` paths remain user-managed. Run one installer at a time. Configs are staged before replacement, but replacement is not an atomic transaction: if it fails after removal, correct the reported error and rerun. No rollback copy is retained.

## zsh

The setup includes zsh, [autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), and [syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting). Existing zsh commands are reused; the plugins are managed through Homebrew. No Oh My Zsh is needed. Your existing prompt and key bindings are kept; a fresh zsh uses its default prompt, tab completion, and a history of at least 10,000 entries (larger existing limits are preserved). Accept suggestions with Right Arrow or End at the end of the line.

The installer appends one guarded loader to `${ZDOTDIR:-$HOME}/.zshrc`, saving an existing regular file beside it as `.zshrc.before-dotfiles.*` first. The loader reads `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/zshrc`, the only zsh config file replaced on updates. Keep the loader last so syntax highlighting follows other plugins. Existing frameworks are not removed or reordered; early returns in a custom `.zshrc` may require placing the loader yourself. Symlinked `.zshrc` files are left untouched and stop the installer for manual integration.

If `.zshenv` sets a custom `ZDOTDIR`, pass that same absolute directory explicitly, for example `ZDOTDIR="$HOME/.config/zsh" bash install.sh`. The installer does not execute your startup files to discover it. Login zsh initializes Homebrew through `.zprofile`, also created when installing from Bash. The managed interactive config only calls `brew shellenv` when PATH needs it, so it does not repeat login initialization. Existing startup lines are left intact.

Keep work-specific settings in `${ZDOTDIR:-$HOME}/.zshrc.local`, which is never created, replaced, or uploaded by the installer. You can customize the prompt there, for example `PROMPT='%F{cyan}%~%f %# '`. Your `.bashrc` is never sourced by zsh or copied into this public repo; the existing Homebrew setup may append its initialization line to Bash startup files. Review and port needed Bash settings individually instead of sourcing `.bashrc` from zsh. Keep private backups outside the checkout.

After applying the configs, each run sets zsh as the current user's default login shell with `chsh` if needed; it may request your account password. An account already using zsh is left alone. The installer prefers a zsh path already in `/etc/shells`. If Homebrew's zsh needs registration there, it explains the exact path and asks before using sudo. Declining or running without an interactive terminal stops with the configs installed but the default shell unchanged. It never changes another user's shell or runs `chsh` with sudo.

Run `zsh` to use it in the current terminal; `exit` returns to the previous shell. Sign out and back in for the new default. Terminal profiles that explicitly launch Bash must be changed manually. Ubuntu/WSL2 is supported; Windows PowerShell is not changed. Bash startup files remain available if you switch back.
