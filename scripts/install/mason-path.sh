# Mason's bin on PATH in future shells, after Homebrew, so tools reused from Mason (ruff,
# stylua, shfmt, ...) work outside Neovim too. The line never adds the folder twice.
# shellcheck disable=SC2016 # written literally; expands when the shell starts
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
mason_line='case ":$PATH:" in *":${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin:"*) ;; *) export PATH="$PATH:${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin" ;; esac'
rc_add "$shell_rc" '^# Mason tools on PATH \(added by dotfiles install\.sh\)$' "$mason_line" \
  '# Mason tools on PATH (added by dotfiles install.sh)'
