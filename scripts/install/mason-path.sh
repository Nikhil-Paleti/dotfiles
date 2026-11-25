# Put Mason's bin directory on PATH for future bash and zsh sessions, after
# Homebrew, so tools the installer reused from Mason (ruff, stylua, shfmt, ...)
# are also available outside Neovim. Safe to rerun: the startup line is added
# once, and the line itself never adds the directory to PATH twice.
##### Mason PATH setup #####
printf '\n##### Mason PATH setup #####\n'
mason_marker='# Mason tools on PATH (added by dotfiles install.sh)'
# Single quotes: the line is written literally and expands when the shell starts.
# shellcheck disable=SC2016
mason_line='case ":$PATH:" in *":${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin:"*) ;; *) export PATH="$PATH:${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin" ;; esac'
case "${SHELL##*/}" in
  zsh) mason_rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
  bash) mason_rc="$HOME/.bashrc" ;;
  *) echo 'Automatic Mason PATH setup supports bash and zsh.' >&2; exit 1 ;;
esac
if grep -Fqx "$mason_marker" "$mason_rc" 2>/dev/null; then
  echo "Already configured in $mason_rc; skipped."
else
  mkdir -p "$(dirname "$mason_rc")"
  printf '\n%s\n%s\n' "$mason_marker" "$mason_line" >> "$mason_rc"
  echo "Added Mason bin to PATH in $mason_rc."
fi
printf '##### end Mason PATH setup #####\n'
##### end Mason PATH setup #####
