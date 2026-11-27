# Dotfiles

LazyVim, shell tools and a keyboard layer, set up by one Bash installer.
Works on macOS and Debian/Ubuntu Linux, including WSL2 (ARM64 and x86_64).

## Install

On macOS, run `xcode-select --install` and let it finish first.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh
```

Then open a new terminal. On a new machine, run `atuin import auto` to bring
in your shell history.

## The dot command

The installer links `dot` into `~/.local/bin`, so it works from any folder.

```sh
dot update                  # pull this repo and rerun the installer
dot kb status               # is the keyboard layer running? (also start, stop)
dot doctor                  # check every piece and say what's broken
dot version                 # version here and the last installs
dot --help                  # every command; dot kb --help for one
```

`dot kb` asks launchd on the Mac, or Windows from WSL, what's running now.
`dot kb stop` lasts until `dot kb start` or the next restart (Windows: login).

## Update

```sh
dot update                  # or: bash ~/dotfiles/install.sh
```

The same command pulls this repo (skipped if you have local changes),
upgrades the tools and moves every Neovim plugin to the version in
`config/nvim/lazy-lock.json`. After `:Lazy update`, commit that file so your
other machines get the same versions. Add `--verbose` to see every command.

> [!WARNING]
> Each run replaces `~/.config/nvim`. Edit the config in this repo, not the
> installed copy.

## Versions

Every commit on main that passes CI gets a dated version, like
`v2026.11.27.1`, and a [release](https://github.com/Nikhil-Paleti/dotfiles/releases)
that lists what changed.

```sh
dot version   # or: bash ~/dotfiles/install.sh --version
```

If a change breaks something, revert it on main and run `install.sh` again.

## What gets installed

| Part           | macOS             | Linux          | WSL2              |
| -------------- | ----------------- | -------------- | ----------------- |
| Packages       | Homebrew          | Homebrew       | Homebrew          |
| System deps    | Xcode CLT, by you | apt, with sudo | apt, with sudo    |
| Keyboard layer | Kanata and driver | skipped        | copies the config |

| Group      | Tools                                                  |
| ---------- | ------------------------------------------------------ |
| Core       | git, jj, gh, curl, bazelisk                            |
| Editor     | Neovim (LazyVim), tree-sitter CLI                      |
| Search     | ripgrep, fd, fzf, lazygit, [scout][scout]              |
| Shell      | Atuin, Starship, zoxide                                |
| bash only  | ble.sh                                                 |
| zsh only   | zsh-autosuggestions, zsh-syntax-highlighting           |
| Languages  | Python, uv, Node.js, npm, Rust via [rustup][rustup]    |
| Formatters | StyLua, shfmt, ShellCheck, Ruff                        |

The Homebrew list is [scripts/components.sh](scripts/components.sh). A tool
already installed another way is reused, not upgraded. Startup lines are added
to `~/.bashrc` or `~/.zshrc` once, and your default shell stays as it is.

## Neovim

- **Theme:** Carbonfox on pure black. Accent colors are `pop` in
  `lua/plugins/carbonfox.lua`.
- **Start screen:** a random pixel-art scene, the folder's recent files and
  the repo status. Set `vim.g.dashboard_scene` to always show one.
- **Languages:** Python, Rust ([rustaceanvim][rustaceanvim] with rustup's
  `rust-analyzer`), markdown and Bazel.
- **Formatting:** nothing on save. Use `Space c f`.
- **Status bar:** the jj bookmark and change, or the git branch and commit.
- **Clipboard:** yanks reach your terminal's clipboard over OSC 52, also over
  SSH. Paste with the terminal's paste key.
- **Code search:** [scout][scout] indexes a git repo when you open it, then
  LazyVim's search and find-file keys use it. Queries follow Google Code
  Search syntax (`scout --help`). Each install builds scout's `main`.
- **GitHub:** run `gh auth login` once, then `:Octo pr list`.

## Shell

- **History:** [Atuin][atuin], local only, no sync. Commands that Claude Code
  or Codex run are kept apart; `atuin search --author '$all-agent'` shows
  them.
- **Suggestions:** ble.sh on bash, zsh-autosuggestions and
  zsh-syntax-highlighting on zsh.
- **Folders:** [zoxide][zoxide] adds `z` and `zi`. `cd` is unchanged.
- **Prompt:** [Starship][starship], showing the jj change and bookmark in jj
  repos.
- **Editor:** `jj`, `git` and `gh` open Neovim.

## Keyboard layer

Hold left space or Caps Lock for numbers, brackets and arrows on the home row.
On the Mac's built-in keyboard it's Caps Lock only. The key map and Mac and Windows setup are in
[config/kanata/README.md](config/kanata/README.md).

## Troubleshooting

- **A new command isn't found:** open a new terminal, or run the `eval` line
  the installer prints.
- **Icons show as boxes:** use a [Nerd Font][nerdfont] in your terminal. On
  Windows Terminal, set it for the WSL profile under
  [Appearance > Font face][wt-font].
- **Something stopped working:** run `dot doctor`; each ✗ line says what to do.
- **A step failed:** fix what it reports and rerun. `--verbose` shows the full
  output.

Ideas not set up yet are in [canexplore.md](canexplore.md).

[atuin]: https://atuin.sh/
[nerdfont]: https://www.nerdfonts.com/
[rustaceanvim]: https://github.com/mrcjkb/rustaceanvim
[rustup]: https://rustup.rs/
[scout]: https://github.com/Nikhil-Paleti/scout
[starship]: https://starship.rs/
[wt-font]: https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance#font-face
[zoxide]: https://github.com/ajeetdsouza/zoxide
