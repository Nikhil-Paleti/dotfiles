# Terminal toolchain installer

Installs missing terminal/editor tools on macOS or Debian/Ubuntu Linux/WSL2
(ARM64/x86_64). Preserves existing configuration. Codex is excluded.

```sh
bash install.sh --check    # default: read-only; exit 1 means missing
bash install.sh --install  # explicitly provision missing tools
bash install.sh --update   # upgrade installed Homebrew tools from this project
```

Run the entry point as your normal user, from any working directory. Modules are
sourced by the entry point and share its PATH and cleanup state; do not run them
individually. Keep the checkout together rather than downloading install.sh alone.
Every component prints matching `##### ... install #####` start/end markers.

## Layout

| File | Responsibility |
| --- | --- |
| `install.sh` | Parse arguments and run modules in dependency order. |
| `scripts/platform.sh` | Validate OS and architecture. |
| `scripts/discover.sh` | Find existing Homebrew and Mason tools before availability checks. |
| `scripts/check.sh` | Report present/missing components; stop in check-only mode. |
| `scripts/update.sh` | Refresh Homebrew and upgrade only installed formulae from this project. |
| `scripts/lib/common.sh` | Shared command checks and component output. |
| `scripts/lib/temp.sh` | Allocate temporary downloads; clean only directories owned by this run. |
| `scripts/lib/publish_config.py` | Publish completed LazyVim config atomically without replacing collisions. |
| `scripts/install/prerequisites.sh` | Check Apple build tools or provision missing Linux build dependencies. |
| `scripts/install/homebrew.sh` | Install Homebrew if absent. |
| `scripts/install/core.sh` | Git and curl. |
| `scripts/install/tmux.sh` | tmux. |
| `scripts/install/neovim.sh` | Neovim executable. |
| `scripts/install/search.sh` | ripgrep, fd, lazygit, fzf. |
| `scripts/install/runtimes.sh` | Python 3, Node.js, npm. |
| `scripts/install/formatters.sh` | Tree-sitter CLI, StyLua, shfmt, ShellCheck. |
| `scripts/install/shell.sh` | zsh, autosuggestions, completions, syntax highlighting. |
| `scripts/install/lazyvim.sh` | Stage, sync and publish a fresh LazyVim starter; skip existing configs. |
| `tests/test_install.py` | Isolated tests with mocked package managers, Git and Neovim. |

## Behavior and limits

Installation needs network access and any required privileges provisioned in
advance. Homebrew runs noninteractively; Linux apt uses `sudo -n`. Fresh macOS
requires Apple command-line tools completed separately. There are no custom version comparisons, pins or lockfiles. Install mode keeps
existing tools; update mode lets Homebrew choose current releases. Update mode
does not install missing tools or update OS packages, tools from other managers,
or Neovim plugins. Homebrew may update dependencies of the selected formulae.
Use `:Lazy update` inside Neovim for LazyVim/plugins. Compatibility with a
particular existing tool version is not checked by this script.

Existing commands, including Mason-managed tools, are reused. A fresh Neovim
configuration is cloned and synced in a temporary directory on the destination
filesystem. Only after sync succeeds is it atomically published, with no replacing
an existing destination. A failed sync leaves the final path absent so rerunning
can retry. Existing config is never executed or replaced. Plugin data/cache may
be downloaded during fresh setup; plugins whose failures do not produce a
nonzero Neovim exit are not independently validated.

No shell-profile edits, default-shell changes, authentication or personal dotfile
migration. Zsh plugins are installed but not enabled. Add Homebrew to future
shells using the command printed at completion. Fonts, terminal settings, Conda,
OrbStack and language-specific extras are outside scope. Native Windows is not
supported; use WSL2.

## Tests

```sh
python3 tests/test_install.py
```

Tests use disposable temporary homes. Package installs, Git cloning and Neovim
sync are mocked; filesystem operations and atomic config publication are real.
They cover read-only checks, missing tools, profiles/config preservation,
idempotence, update scope/deduplication, retry after sync failure, concurrent collision refusal, incompatible
arguments, and hostile inherited cleanup paths. Real provisioning
and Linux/WSL integration have not been tested.

Sources: [LazyVim](https://www.lazyvim.org/installation),
[Homebrew installation](https://docs.brew.sh/Installation),
[Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux).
