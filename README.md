# Dotfiles

Personal LazyVim configuration and a Bash installer for command-line tools.

## Install

- Targets macOS and Debian/Ubuntu (including WSL2), on ARM64 or x86_64.
- Requires Bash, Git to clone this repo, and internet access.
- Ubuntu prerequisites use `apt-get` and `sudo` when needed. On macOS, finish `xcode-select --install` first.

Run as your normal user, **not with `sudo bash`**. System setup can prompt for your password.

**Warning:** Every `--install` run replaces `${XDG_CONFIG_HOME:-$HOME/.config}/nvim` with [this repo's config](config/nvim). Existing config is backed up first; see below. Keep the checkout outside that destination.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh --install
```

Missing tools use Homebrew, installed if needed; existing commands are reused. Follow the printed Homebrew `shellenv` instruction for future shells. zsh plugins are installed but not enabled, and your default shell is unchanged.

Open `nvim` to install editor plugins, then run `:LazyHealth` and `:checkhealth mason`.

## Update

From the repo directory:

```sh
bash install.sh --update
```

Upgrades installed Homebrew packages from the [tool list](scripts/components.sh); it doesn't install missing tools or replace config. Manage Neovim plugins with `:Lazy update` and Mason packages inside Neovim. Use `bash install.sh --help` for usage.

## Backups and restore

Backups stay beside `nvim`, named `nvim_backup`, then `nvim_backup.1`, `nvim_backup.2`, etc. The installer prints the actual path and never deletes backups automatically.

To restore, close Neovim, move the current `nvim` path aside to an unused name, then rename your chosen backup to `nvim`. Run only one installer at a time; if replacement fails, follow its recovery message.

## Testing

Ubuntu ARM64 has been exercised. Native macOS and other platform combinations remain unvalidated; mocked tests are not a substitute for those runs.
