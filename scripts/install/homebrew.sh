# Install Homebrew as the current user, allowing its normal setup prompts.
##### Homebrew install #####
printf '\n##### Homebrew install #####\n'
if ! have brew; then
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$_dotfiles_download_dir/homebrew.sh"
  /bin/bash "$_dotfiles_download_dir/homebrew.sh"
  for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [[ -x "$prefix/bin/brew" ]]; then export PATH="$prefix/bin:$prefix/sbin:$PATH"; break; fi
  done
fi
have brew || { echo 'Homebrew unavailable after installation.' >&2; exit 1; }
# Add Homebrew to future shells without replacing existing startup content.
case "${SHELL##*/}" in
  zsh) profiles=("${ZDOTDIR:-$HOME}/.zprofile" "${ZDOTDIR:-$HOME}/.zshrc") ;;
  bash)
    login_profile="$HOME/.profile"
    [[ ! -f "$HOME/.bash_login" ]] || login_profile="$HOME/.bash_login"
    [[ ! -f "$HOME/.bash_profile" ]] || login_profile="$HOME/.bash_profile"
    profiles=("$login_profile" "$HOME/.bashrc")
    ;;
  *) echo 'Automatic Homebrew setup supports bash and zsh.' >&2; exit 1 ;;
esac
printf -v shellenv_line 'eval "$("%s" shellenv)"' "$(command -v brew)"
for profile in "${profiles[@]}"; do
  if ! grep -Eq '^[[:space:]]*eval[[:space:]].*shellenv' "$profile" 2>/dev/null; then
    mkdir -p "$(dirname "$profile")"
    printf '\n%s\n' "$shellenv_line" >> "$profile"
  fi
done
printf '##### end Homebrew install #####\n'
##### end Homebrew install #####
