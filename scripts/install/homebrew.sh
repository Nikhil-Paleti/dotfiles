# Homebrew as the current user (its installer may prompt), then on PATH for future shells.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
step Homebrew
brew_new=false
if ! have brew; then
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$_dotfiles_download_dir/homebrew.sh"
  run_live /bin/bash "$_dotfiles_download_dir/homebrew.sh"
  load_brew
  brew_new=true
fi
have brew || die 'Homebrew unavailable after installation.'
# Add shellenv to the login profile and the rc file, unless a shellenv line is already there.
if [[ "$login_shell" == zsh ]]; then
  brew_profile="${ZDOTDIR:-$HOME}/.zprofile"
else
  brew_profile="$HOME/.profile"
  [[ ! -f "$HOME/.bash_login" ]] || brew_profile="$HOME/.bash_login"
  [[ ! -f "$HOME/.bash_profile" ]] || brew_profile="$HOME/.bash_profile"
fi
# shellcheck disable=SC2016 # literal startup line; expands when the shell starts
printf -v shellenv_line 'eval "$("%s" shellenv)"' "$(command -v brew)"
for profile in "$brew_profile" "$shell_rc"; do
  if ! grep -Eq '^[[:space:]]*eval[[:space:]].*shellenv' "$profile" 2>/dev/null; then
    mkdir -p "$(dirname "$profile")"
    printf '\n%s\n' "$shellenv_line" >> "$profile"
    dotfiles_rc_changes+=("$profile")
  fi
done
if [[ "$brew_new" == true ]]; then ok installed; else ok; fi
