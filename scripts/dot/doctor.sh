# `dot doctor`: check each piece install.sh sets up, one line each, and say what to do about
# anything broken. Reads only; changes nothing. Exits 1 if something is broken.
# shellcheck disable=SC2154 # globals come from the files sourced below
dot_doctor() {
  [[ $# -eq 0 ]] || { echo 'Usage: dot doctor' >&2; return 2; }
  source "$DOTFILES_ROOT/scripts/lib/common.sh"
  source "$DOTFILES_ROOT/scripts/platform.sh"
  source "$DOTFILES_ROOT/scripts/components.sh"
  source "$DOTFILES_ROOT/scripts/version.sh"
  # Tools that are installed but not loaded in this shell (Homebrew, Mason, cargo), as install.sh
  # finds them. A new shell finding them is the Shell startup check.
  source "$DOTFILES_ROOT/scripts/discover.sh"
  local cargo_bin="${CARGO_HOME:-$HOME/.cargo}/bin"
  [[ ! -d "$cargo_bin" ]] || case ":$PATH:" in *":$cargo_bin:"*) ;; *) PATH="$cargo_bin:$PATH" ;; esac
  source "$DOTFILES_ROOT/scripts/dot/kb.sh"

  local problems=0
  # A failed check: the ✗ line, then what to do about it.
  doctor_fail() { fail "$1"; shift; note "$@"; problems=$((problems + 1)); }

  step 'Dotfiles repo'
  ok "$(dotfiles_version) at $(short_path "$DOTFILES_ROOT")"

  step 'dot command'
  local dot_path dot_real want
  dot_path=$(command -v dot || true)
  want="$(cd -P "$DOTFILES_ROOT/bin" && pwd)/dot"
  dot_real=$(doctor_resolve "$dot_path")
  if [[ -z "$dot_path" ]]; then
    doctor_fail 'not on PATH' 'Open a new terminal, or run bash install.sh.'
  elif [[ "$dot_real" != "$want" ]]; then
    doctor_fail "$(short_path "$dot_path") is not this repo's" "Remove it, then run dot update."
  else
    ok "$(short_path "$dot_path")"
  fi

  step Homebrew
  if have brew; then ok; else doctor_fail 'not found' 'Run dot update.'; fi

  step Tools
  local item tool missing=() count=0
  for item in "${requirements[@]}"; do
    tool=${item%%:*}
    [[ -n "$tool" ]] || continue
    count=$((count + 1))
    have "$tool" || missing+=("$tool")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then ok "$count commands"
  else doctor_fail "missing ${missing[*]}" 'Run dot update.'; fi

  step Rust
  if ! have cargo; then
    doctor_fail 'cargo not found' 'Run dot update.'
  elif ! rust-analyzer --version >/dev/null 2>&1; then
    doctor_fail "rust-analyzer does not run, so Neovim can't use it" 'Run dot update.'
  else
    local cargo_version
    cargo_version=$(cargo --version)
    ok "${cargo_version%% (*}"
  fi

  step scout
  local scout_dir="$DOTFILES_ROOT/modules/scout"
  if [[ ! -x "$scout_dir/target/release/scout" ]]; then
    doctor_fail "no build in $(short_path "$scout_dir")" 'Run dot update.'
  elif ! have scout; then
    doctor_fail 'not on PATH' 'Run dot update.'
  else
    ok "$(git -C "$scout_dir" log -1 --format='%h, %cs' 2>/dev/null || echo built)"
  fi

  step 'Neovim config'
  local nvim_config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
  if [[ ! -f "$nvim_config/init.lua" ]]; then
    doctor_fail "$(short_path "$nvim_config") is missing" 'Run dot update.'
  elif ! cmp -s "$DOTFILES_ROOT/config/nvim/init.lua" "$nvim_config/init.lua" ||
    ! diff -rq -x dotfiles_root.lua "$DOTFILES_ROOT/config/nvim/lua" "$nvim_config/lua" >/dev/null 2>&1 ||
    ! grep -Fq "$DOTFILES_ROOT" "$nvim_config/lua/dotfiles_root.lua" 2>/dev/null; then
    doctor_fail "$(short_path "$nvim_config") differs from the repo" \
      'Run dot update. It replaces the installed copy, so make edits in the repo.'
  else
    ok
  fi

  step 'Shell startup'
  local gaps=() pattern
  for pattern in 'atuin init' 'starship init' 'zoxide init' '\.local/bin'; do
    grep -Eq -- "$pattern" "$shell_rc" 2>/dev/null || gaps+=("${pattern//\\/}")
  done
  if [[ "$login_shell" == bash && ! -f "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" ]]; then gaps+=(ble.sh); fi
  if [[ "$login_shell" == zsh ]] && have brew; then
    local brew_installed
    brew_installed=$(brew list --formula -1 2>/dev/null || true)
    for item in "${zsh_plugins[@]}"; do
      grep -qxF -- "${item#*:}" <<<"$brew_installed" || gaps+=("${item#*:}")
    done
  fi
  cmp -s "$DOTFILES_ROOT/config/atuin/config.toml" "${ATUIN_CONFIG_DIR:-$HOME/.atuin}/config.toml" || gaps+=('Atuin config')
  cmp -s "$DOTFILES_ROOT/config/starship/starship.toml" "${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}" ||
    gaps+=('Starship config')
  if [[ ${#gaps[@]} -eq 0 ]]; then ok "$(short_path "$shell_rc")"
  else doctor_fail "missing $(printf '%s, ' "${gaps[@]}" | sed 's/, $//')" 'Run dot update, then open a new terminal.'; fi

  step 'Keyboard layer'
  local kb_msg kb_status=0
  if [[ -n "${CI:-}" ]]; then
    skip 'CI has no keyboard'
  else
    case "$(kb_where)" in
      mac)
        kb_msg=$(kb_mac_report 2>&1) || kb_status=$?
        if ((kb_status)); then doctor_fail 'Kanata' "$kb_msg"; else ok; note "$kb_msg"; fi
        ;;
      wsl)
        local appdata win_cfg
        appdata=$(win_appdata_path)
        win_cfg=$( [[ -z "$appdata" ]] || wslpath -u "$appdata\\kanata\\kanata.kbd" 2>/dev/null || true)
        kb_msg=$(kb_wsl_status 2>&1) || kb_status=$?
        if [[ -z "$win_cfg" ]] || ! cmp -s "$DOTFILES_ROOT/config/kanata/kanata.kbd" "$win_cfg"; then
          doctor_fail 'the Windows config is not the repo one' 'Run dot update, then pick Reload in the Kanata tray menu.'
        elif ((kb_status)); then
          doctor_fail 'Kanata' "$kb_msg"
        else
          ok; note "$kb_msg"
        fi
        ;;
      *) skip 'Kanata runs on the Mac or Windows machine with the keyboard' ;;
    esac
  fi

  step 'Last install'
  local last
  last=$(tail -n 1 "$dotfiles_state/installs.log" 2>/dev/null || true)
  if [[ -n "$last" ]]; then ok "$last"; else skip 'none recorded on this machine'; fi

  echo
  if ((problems == 0)); then
    echo 'All good.'
  else
    echo "$problems problem$( ((problems == 1)) || echo s) found."
    return 1
  fi
}

# The file a path finally points to, following symlinks, with its folder resolved too.
doctor_resolve() {
  local path=$1 link
  [[ -n "$path" ]] || return 0
  while [[ -L "$path" ]]; do
    link=$(readlink "$path")
    case "$link" in /*) path=$link ;; *) path="$(dirname "$path")/$link" ;; esac
  done
  printf '%s/%s' "$(cd -P "$(dirname "$path")" 2>/dev/null && pwd)" "$(basename "$path")"
}
