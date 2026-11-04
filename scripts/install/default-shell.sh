# Change only the current user's login shell, after the config is ready.
current_user="$(id -un)"
login_shell() {
  if [[ "$os" == Darwin ]]; then
    dscl /Search -read "/Users/$current_user" UserShell | awk '$1 == "UserShell:" { print $2 }'
  else
    getent passwd "$(id -u)" | cut -d: -f7
  fi
}
current_shell="$(login_shell)"
[[ -n "$current_shell" ]] || { echo 'Could not read your account shell; no shell change attempted.' >&2; exit 1; }
if [[ "${current_shell##*/}" == zsh && -x "$current_shell" ]]; then
  echo "Your login shell is already zsh: $current_shell"
else
  have chsh || { echo 'chsh is unavailable; ask your system administrator to set zsh as your login shell.' >&2; exit 1; }
  zsh_path="$(type -P zsh)"
  case "$zsh_path" in /*) ;; *) echo 'Expected an absolute zsh executable path.' >&2; exit 1 ;; esac
  # Prefer an already approved zsh over changing the system's allowed-shell list.
  if ! grep -Fqx -- "$zsh_path" /etc/shells; then
    for candidate in /bin/zsh /usr/bin/zsh; do
      if [[ -x "$candidate" ]] && grep -Fqx -- "$candidate" /etc/shells; then
        zsh_path="$candidate"
        break
      fi
    done
  fi
  if ! grep -Fqx -- "$zsh_path" /etc/shells; then
    printf 'zsh is installed at %s, but that path is not allowed in /etc/shells.\n' "$zsh_path"
    [[ -t 0 ]] || { echo 'Run this installer in an interactive terminal to approve registration, or ask your administrator.' >&2; exit 1; }
    read -r -p 'Allow adding this exact path to /etc/shells with sudo? [y/N] ' allow_shell
    case "$allow_shell" in
      y|Y|yes|YES)
        have sudo || { echo 'sudo is unavailable; ask your administrator to register the shell.' >&2; exit 1; }
        sudo sh -c 'grep -Fqx -- "$1" /etc/shells || printf "\n%s\n" "$1" >> /etc/shells' sh "$zsh_path"
        ;;
      *) echo 'Shell registration declined; your default shell is unchanged. You can still run zsh.'; exit 1 ;;
    esac
  fi
  printf 'Changing the login shell for %s to %s; chsh may ask for your account password.\n' "$current_user" "$zsh_path"
  chsh -s "$zsh_path" "$current_user"
  [[ "$(login_shell)" == "$zsh_path" ]] || { echo 'Could not verify the shell change; check your account settings before retrying.' >&2; exit 1; }
  echo 'Default shell changed to zsh. Sign out and back in; this running shell stays as it is.'
fi
