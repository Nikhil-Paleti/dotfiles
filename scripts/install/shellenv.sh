# Make Homebrew available in future login and interactive shells.
# Never source startup files here: they may contain unrelated user commands.
configured_shell="${SHELL:-}"
case "$os:${configured_shell##*/}" in
  Darwin:zsh)
    shell_home="${ZDOTDIR:-$HOME}"
    case "$shell_home" in /*) ;; *) echo 'ZDOTDIR must be absolute.' >&2; exit 1 ;; esac
    profiles=("$shell_home/.zprofile" "$shell_home/.zshrc")
    ;;
  Linux:bash)
    login_profile="$HOME/.profile"
    for candidate in "$HOME/.bash_profile" "$HOME/.bash_login"; do
      if [[ -e "$candidate" || -L "$candidate" ]]; then login_profile="$candidate"; break; fi
    done
    profiles=("$login_profile" "$HOME/.bashrc")
    ;;
  *) echo 'Automatic Homebrew setup supports macOS zsh and Linux bash; set SHELL to your configured shell and retry.' >&2; exit 1 ;;
esac
brew_command=$(command -v brew) || { echo 'Homebrew is not available for startup setup.' >&2; exit 1; }
[[ "$brew_command" == /* && -x "$brew_command" ]] || { echo 'Homebrew must resolve to an executable absolute path.' >&2; exit 1; }
# Single-quote the executable for both bash and zsh, including apostrophes.
quote_escape="'\\''"
brew_quoted="'${brew_command//\'/$quote_escape}'"
for profile in "${profiles[@]}"; do
  [[ ! -L "$profile" && ( ! -e "$profile" || -f "$profile" ) ]] || {
    printf 'Cannot safely append Homebrew setup to %s: expected a regular file, not a symlink or directory.\n' "$profile" >&2; exit 1;
  }
  [[ ! -e "$profile" || -w "$profile" ]] || { printf 'Startup file is not writable: %s\n' "$profile" >&2; exit 1; }
done
for profile in "${profiles[@]}"; do
  # Keep an existing explicit shellenv customization instead of adding another.
  if [[ -f "$profile" ]] && grep -Eq '^# dotfiles: Homebrew shellenv$|^[[:space:]]*eval[[:space:]].*shellenv' "$profile"; then
    continue
  fi
  mkdir -p "$(dirname "$profile")"
  {
    printf '\n# dotfiles: Homebrew shellenv\n'
    printf 'if ! command -v brew >/dev/null 2>&1 && [ -x %s ]; then\n' "$brew_quoted"
    printf '  eval "$(%s shellenv)"\n' "$brew_quoted"
    printf 'fi\n'
  } >> "$profile" || { printf 'Could not append Homebrew setup to %s\n' "$profile" >&2; exit 1; }
done
printf 'Homebrew startup setup checked: %s\n' "${profiles[*]}"
