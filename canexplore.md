# Can explore

Tools and setup ideas to try later. When one earns a place, add it to the installer
and move it out of this list.

## Fixes for tools already here

- **`EDITOR=nvim`**: `EDITOR` is unset, so `jj describe`, `git commit`, `gh pr create`, and
  `crontab -e` open nano. One line in the shell rc file.
- **[delta](https://github.com/dandavison/delta)**: syntax-highlighted, side-by-side-capable
  diffs with line numbers for `git diff`, `git log -p`, `jj diff`, and lazygit. Set it as the
  pager in git and jj config.
- **fzf shell keys**: fzf is installed but only Neovim uses it. `Ctrl+T` pastes a fuzzy-picked
  file path, `Alt+C` jumps into a fuzzy-picked folder. Atuin keeps `Ctrl+R`.

## New tools

- **[zoxide](https://github.com/ajeetdsouza/zoxide)**: a `cd` that learns where you go.
  `z gpu` jumps to `~/projects/gpu-programming`; `zi` fuzzy-picks. Good for deep monorepo paths.
- **[bat](https://github.com/sharkdp/bat)**: `cat` with syntax highlighting, line numbers, and
  git change markers; also nicer file previews in fzf.
- **[eza](https://github.com/eza-community/eza)**: modern `ls` with colors, Nerd Font icons,
  per-file git status, and a tree view.
- **[direnv](https://direnv.net/)**: per-folder environment variables that load when you enter
  a project and unload when you leave (e.g. `CUDA_HOME`, work settings).
- **[jq](https://jqlang.org/)**: query and pretty-print JSON.
- **[btop](https://github.com/aristocratos/btop)**: a much nicer `top` (CPU, memory, disks,
  network; not GPU).
- **[tldr](https://tldr.sh/)**: short, example-first command help instead of `man`.
- **[just](https://github.com/casey/just)**: a simple per-project task runner.

## Neovim

- **clangd for CUDA/C++**: hover docs, completion, go to definition, and errors in `.cu` files.
  Plan: Bazel-generated `compile_commands.json` (Hedron's extractor) plus a `.clangd` fallback
  for non-Bazel files; check first that the clangd version supports CUDA 13.3 and `sm_120`.
  At work, CUDA is hermetic (fetched by Bazel), which changes paths and `--cuda-path`.
- **Bazel task runner**: overseer.nvim with a small Bazel template, so build errors jump to the
  file and line.
- **jj in Neovim**: jjui in a floating window (like lazygit), or hunk.nvim as jj's
  split/squash diff editor.
- **Start screen home key**: a shortcut to reopen the start screen (`:lua Snacks.dashboard()`).

## Shell

- **Atuin sync**: end-to-end encrypted history across machines, through Atuin's server or a
  self-hosted one (e.g. on the always-on Jetson).
- **Atuin extras**: output capture (needs the daemon), and threads/agent hooks for AI coding
  sessions (the agent hooks edit `~/.claude/settings.json`).

## Machine setup

- **Record the WSL boot setup**: the Windows scheduled task that boots WSL at startup and keeps
  it running (`wsl.exe -d Ubuntu --exec /bin/sleep infinity`), the Rex server
  (`rex server install`), and Tailscale SSH in WSL. Today it exists only on this machine.
- **Rex channel**: Rex in WSL is on the snapshot channel; preview matches the Mac.
