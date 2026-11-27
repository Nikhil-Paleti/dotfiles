# Versions: CI tags every commit on main that passes as vYYYY.MM.DD.N (.github/workflows/release.yml).
# Each finished install adds a line to installs.log, so you can see what ran when.
dotfiles_state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"

# This checkout's version: a tag, or the last tag plus commits since (v2026.11.27.1-3-gabc1234).
dotfiles_version() {
  git -C "$DOTFILES_ROOT" describe --tags --match 'v[0-9]*' --always 2>/dev/null || printf 'unknown'
}

dotfiles_record_install() {
  local log="$dotfiles_state/installs.log"
  mkdir -p "$dotfiles_state"
  printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M')" "$(dotfiles_version)" >>"$log"
  # Keep the last 100 installs.
  if [[ $(wc -l <"$log") -gt 100 ]]; then
    tail -n 100 "$log" >"$log.tmp" && mv "$log.tmp" "$log"
  fi
}

dotfiles_show_version() {
  printf 'dotfiles %s\n' "$(dotfiles_version)"
  if [[ -s "$dotfiles_state/installs.log" ]]; then
    printf '\nLast installs on this machine:\n'
    tail -n 10 "$dotfiles_state/installs.log" | sed 's/^/  /'
  fi
}
