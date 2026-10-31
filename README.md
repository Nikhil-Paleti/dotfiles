# Portable dotfiles

Snapshot of the existing Mac LazyVim and tmux setup. Nothing has been installed on the source Mac. Installation stays manual and opt-in.

## What's preserved

- `config/nvim/`: original configuration, plugin lockfile, formatter settings, metadata, and Apache license. Includes `ishiooon/codex.nvim`; the example plugin spec remains disabled as in the source.
- `tmux.conf`: exact original; Ctrl+A prefix, mouse, Vim pane navigation, Shift+H/J/K/L resizing. Ctrl+B is unbound.
- `shell/`: portable adaptations of the existing zsh files. Homebrew and OrbStack are conditional. Anaconda initialization stays machine-local because its path is installation-specific.

Ctrl+[ already acts as Escape in normal terminal Neovim use. No new keymap or pane ratio was invented. Resize your editor/agent panes using Ctrl+A then Shift+H/L; there is no saved fixed ratio in the original setup.

## Preview and install

Requires Python 3. First inspect the files. On macOS, Linux, or WSL:

```sh
python3 bootstrap.py --dry-run
python3 bootstrap.py --components nvim tmux --dry-run
# Only when ready:
python3 bootstrap.py --components nvim tmux --apply
```

The installer copies files, never relinks them, installs packages, launches programs, or overwrites existing destinations. It preflights all selected targets and refuses collisions, including dangling symlinks and symlinked target parents. Dry-run is the default. It ignores XDG_CONFIG_HOME and always targets HOME/.config/nvim; use the standard location or install manually. Copies are independent: update them deliberately after pulling changes. Filesystem errors during copying may leave partial new files; review/remove only those new destinations before retrying.

On the original Mac the installer will refuse the existing configuration. Back up and compare files manually rather than replacing them blindly. To undo a fresh install, remove only the newly copied destinations after preserving any edits.

## Machine overrides

Keep `.zshrc.local` and `.zprofile.local` in each machine's home, outside this repo. Put local conda initialization, work PATHs and environment configuration there. A Linux/WSL conda installation will have a different path. Secrets belong in a secret manager or local environment, never in Git.

For Neovim, add machine-only plugin specs at `lua/plugins/local.lua` in the installed copy; LazyVim imports that directory. Local options may be placed at `lua/config/local.lua` and explicitly required from the installed `options.lua`. These names are ignored in this repo. Keep tmux machine additions in your installed copy and do not commit them inadvertently.

## Platforms and dependencies

- macOS: zsh, tmux and Neovim must already be installed. Optional Homebrew shell plugins are sourced only if present.
- Linux / work VMs: tmux and Neovim configuration is portable; shell files apply only if you actually use zsh. Do not install shell files over an existing work setup. Check employer policy before enabling Codex or external plugins.
- Windows: run this installer inside WSL, with tools installed inside that distribution. Native Windows Neovim uses a different config location (typically LOCALAPPDATA/nvim); copy the nvim directory manually if desired. tmux/zsh are not native Windows configurations.
- Neovim's existing Lazy bootstrap downloads plugins when Neovim is first launched, and may install language tooling. The installer itself performs no downloads. `lazy-lock.json` records the captured revisions; use Lazy's restore command when you want those pinned versions. Runtime/tool compatibility and Windows behavior were not verified.
- Codex CLI and authentication are separate per machine and never copied here.

## Privacy and verification

Only allowlisted configuration was copied. No SSH files, shell history, Codex auth/sessions, environment files, caches, work projects or Git identity are included. Shell changes are documented above; Neovim and tmux files remain byte-for-byte source snapshots.

Run `python3 tests/test_bootstrap.py` for temporary-home tests covering dry-run, fresh install, repeat installation, collision preflight, broken symlinks and unsafe parent links. Tests do not install into your real home. This does not prove Neovim plugin compatibility or test on Linux/WSL.
