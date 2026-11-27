# Dotfiles

Personal LazyVim configuration and a Bash installer for command-line tools.

## Install or update

On macOS, finish `xcode-select --install` first.

```sh
git clone https://github.com/Nikhil-Paleti/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

Use the same command every time. It upgrades installed Homebrew packages from the [tool list](scripts/components.sh), installs missing tools, and applies the repo Neovim config. Existing commands from other package managers are reused, not upgraded or replaced. Homebrew is installed if needed and set up automatically for future bash and zsh sessions. Neovim's Mason `bin` directory is also added to `PATH` in `~/.bashrc` or `~/.zshrc` (after Homebrew, once, without duplicates), so tools reused from Mason, such as `ruff`, work in the terminal too. Rust and cargo come from [rustup](https://rustup.rs/) (per user, no sudo; stable toolchain with `rustfmt` and `clippy`), and each run updates them with `rustup update`. A Rust that rustup doesn't manage, such as Homebrew's `rust` formula, is reused instead, since rustup won't install beside it; uninstall it and rerun to switch. Cargo's `bin` directory goes first on `PATH` in `~/.bashrc` or `~/.zshrc` (once, and skipped if a startup file already loads rustup's `~/.cargo/env`), so `cargo install`ed tools work too. The installer cannot change the PATH of the terminal that launched it: open a new terminal, or run the exact `eval` command printed at the end. Your default shell is unchanged.

Carbonfox is the default Neovim theme, with a pure black background for OLED screens and more saturated accent colors (tune `pop` in `lua/plugins/carbonfox.lua`). The start screen (`nvim` or `nvim .`) shows a pixel-art landscape picked at random each time (mountains, aurora, desert, city, lighthouse, rain, village, or space; set `vim.g.dashboard_scene` to pin one), the folder's recent files and the repo status with its jj bookmark or git branch; `Space e` opens the file explorer as a centered popup with a preview, closing once you open a file (inside it, `a` adds a file or folder, `r` renames, `d` deletes, `/` filters by name, and `Space /` searches the highlighted folder: with scout in an indexed repo, else with grep). The status bar shows the jj bookmark and working-copy change (or the git branch and commit) in place of LazyVim's bare commit hash. It never runs jj or git while drawing: it refetches in the background after a save, a `:!` command, a closed terminal (lazygit), a folder change or Neovim regaining focus, and `:BranchRefresh` refetches now; the list of events is at the top of `lua/repo_head.lua`. Open `nvim` to install editor plugins, then run `:LazyHealth` and `:checkhealth mason`.

Neovim has Python, markdown, and Bazel support (`BUILD`, `.bzl`, and `.bazelrc` files). Nothing is formatted on save; format the current file with `Space c f`. On Linux, the installer adds ICU (`libicuN`), which the markdown language server needs. Yanks use the OSC 52 clipboard, so they reach the clipboard of whatever terminal you view Neovim in, including over SSH. `p` pastes Neovim's own last yank instantly instead of asking the terminal; paste from the system clipboard with your terminal's paste key (Cmd+V on the Mac).

Code search in big repos uses [scout](https://github.com/Nikhil-Paleti/scout), an indexed regex search. The installer keeps a checkout of scout's `main` branch in `modules/scout` inside this repo (git-ignored, so deleting the repo deletes it), pulls it on every run, and builds it with `cargo install`, so `scout` works in the terminal too. Neovim loads the plugin from that same folder, so the plugin and the binary always come from one commit; rerun `bash install.sh` to update scout (`:Lazy update` doesn't touch it). Opening Neovim in a git repo starts indexing it in the background (also after `:cd` into another repo; `$HOME` and folders outside git are skipped). Once a repo is indexed, `Space /`, `Space s g` and `Space s w` search scout's index there and `Space Space` and `Space f f` find files through it; until then they stay on the Snacks picker. Queries follow Google Code Search syntax (`file:`, `lang:`, `OR`, `-term`; `scout --help` lists them). `Space s y` lists definitions of the word under the cursor, `Space s x` its callers (matched by name), and `Space s .` searches the current file's folder. Indexes live in `~/.cache/scout` on this machine only. `:checkhealth scout` shows the binary and index state.

The shell gets [Atuin](https://atuin.sh/) for searchable history: `Ctrl+R` searches everything full screen (press `Ctrl+R` again to narrow to this machine, session, folder, or repo), and `Up` searches this terminal's history in a small panel. It is local only: no account, no sync, no update check. If Claude Code or Codex is installed, the installer also has Atuin record the shell commands they run, tagged by agent and hidden from your own searches (`atuin search --author '$all-agent'` shows them). Its settings live in [config/atuin/config.toml](config/atuin/config.toml). On bash, [ble.sh](https://github.com/akinomyoga/ble.sh) adds fish-style suggestions as you type (accept with `→`), syntax highlighting, and a `Tab` completion menu; On zsh, Homebrew's `zsh-autosuggestions` (fed by Atuin) and `zsh-syntax-highlighting` do the same, with zsh's `Tab` menu turned on (the installer also removes group write access from Homebrew's `share` folder, which zsh's completion system otherwise flags as insecure). [zoxide](https://github.com/ajeetdsouza/zoxide) learns the folders you visit: `z gpu` jumps to the best match (such as `~/projects/gpu-programming`), and `zi` picks one with fzf. `cd` is unchanged. The prompt is [Starship](https://starship.rs/), configured in [config/starship/starship.toml](config/starship/starship.toml); in jj repos it shows the working-copy change and nearest bookmark instead of git's detached commit. `EDITOR` and `VISUAL` are set to `nvim` (unless your rc file already sets `EDITOR`), so `jj describe`, `git commit`, and `gh` open Neovim. The installer adds their startup lines to `~/.bashrc` or `~/.zshrc` only when missing (at the end, except zoxide's, which goes above the ble.sh or syntax-highlighting line that has to stay last) and never changes anything else there. Run `atuin import auto` once on a new machine to bring in existing shell history.

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
