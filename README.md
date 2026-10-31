# Terminal toolchain installer

Installs missing terminal/editor tools on macOS or Debian/Ubuntu Linux/WSL2
(ARM64/x86_64). Preserves existing configuration. Codex is excluded.

```sh
bash install.sh --check    # default: read-only; exit 1 means missing/incompatible
bash install.sh --install  # explicitly provision missing tools
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
| `scripts/preflight.sh` | Close stdin and refuse incompatible existing Git/Neovim. |
| `scripts/lib/common.sh` | Shared command/version checks and component output. |
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
requires Apple command-line tools completed separately. Existing Git below 2.19
or Neovim below 0.11.2 causes refusal rather than silently changing another
package manager's installation.

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
idempotence, retry after sync failure, concurrent collision refusal, incompatible
versions, bad arguments, and hostile inherited cleanup paths. Real provisioning
and Linux/WSL integration have not been tested.

Sources: [LazyVim](https://www.lazyvim.org/installation),
[Homebrew installation](https://docs.brew.sh/Installation),
[Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux).
