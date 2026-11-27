# Shell extras: Atuin (history), Starship (prompt), zoxide (z and zi), and suggestions plus
# syntax highlighting (ble.sh for bash, zsh plugins for zsh). Startup lines are added once.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
install_tools 'Atuin, Starship, zoxide' atuin starship zoxide

# Record AI agents' shell commands, tagged and hidden from your own history search (see them with
# atuin search --author '$all-agent'). Needs Atuin 18.25+; an older non-Homebrew atuin is left alone.
step 'Atuin agent history'
if [[ "$(atuin setup --help 2>/dev/null)" != *--agent-history* ]]; then
  skip "$(atuin --version) at $(command -v atuin) is older than 18.25"
else
  agents=()
  for agent in claude:claude-code codex:codex; do
    have "${agent%%:*}" || continue
    run atuin setup --only --agent-history --agents "${agent#*:}" </dev/null
    agents+=("${agent#*:}")
  done
  if [[ ${#agents[@]} -gt 0 ]]; then ok "${agents[*]}"; else skip 'no Claude Code or Codex'; fi
fi

# bash only. Not in Homebrew; its author recommends the nightly build.
step ble.sh
blesh_dir="${XDG_DATA_HOME:-$HOME/.local/share}/blesh"
if [[ "$login_shell" != bash ]]; then
  skip "shell is $login_shell"
elif [[ -f "$blesh_dir/ble.sh" ]]; then
  run bash "$blesh_dir/ble.sh" --update </dev/null
  ok "$(bash "$blesh_dir/ble.sh" --version | head -n 1)"
else
  curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
    -o "$_dotfiles_download_dir/ble-nightly.tar.xz"
  tar -xJf "$_dotfiles_download_dir/ble-nightly.tar.xz" -C "$_dotfiles_download_dir"
  run bash "$_dotfiles_download_dir/ble-nightly/ble.sh" --install "$(dirname "$blesh_dir")"
  ok installed
fi

# zsh only: the zsh counterparts of ble.sh. Formulas without a command, so not in the tool list.
step 'zsh plugins'
if [[ "$login_shell" != zsh ]]; then
  skip "shell is $login_shell"
else
  for formula in zsh-autosuggestions zsh-syntax-highlighting; do
    if brew list --formula --versions "$formula" >/dev/null 2>&1; then
      run brew upgrade --formula "$formula"
    else
      run brew install "$formula"
    fi
  done
  # compinit asks "Ignore insecure directories?" in every new shell when other users can write
  # to a completion folder, and Homebrew's share folder often allows that.
  chmod -R go-w "$(brew --prefix)/share"
  ok
fi

step 'Shell config'
# The repo's Atuin and Starship configs replace the installed ones.
atuin_config_dir="${ATUIN_CONFIG_DIR:-$HOME/.atuin}"
mkdir -p "$atuin_config_dir"
cp "$DOTFILES_ROOT/config/atuin/config.toml" "$atuin_config_dir/config.toml"
starship_config="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"
mkdir -p "$(dirname "$starship_config")"
cp "$DOTFILES_ROOT/config/starship/starship.toml" "$starship_config"
# Like rc_add, but a missing line goes above the first line matching ANCHOR (and this installer's
# comment over it), for lines that must stay last. Without the anchor it is appended.
rc_add_before() {
  local rc="$1" pattern="$2" line="$3" anchor="$4" staged="$_dotfiles_download_dir/rc-insert"
  if grep -Eq "$pattern" "$rc" 2>/dev/null || ! grep -Eq "$anchor" "$rc" 2>/dev/null; then
    rc_add "$rc" "$pattern" "$line"
    return
  fi
  ANCHOR="$anchor" LINE="$line" awk '
    { lines[NR] = $0 }
    END {
      marker = "# Added by dotfiles install.sh"
      for (i = 1; i <= NR; i++) if (lines[i] ~ ENVIRON["ANCHOR"]) break
      at = (i > 1 && lines[i - 1] == marker) ? i - 1 : i
      for (j = 1; j <= NR; j++) {
        if (j == at) printf "%s\n%s\n\n", marker, ENVIRON["LINE"]
        print lines[j]
      }
    }' "$rc" >"$staged"
  # Write through the file so its permissions and any symlink stay.
  cat "$staged" >"$rc"
  detail "Added to $rc, above $anchor: $line"
  dotfiles_rc_changes+=("$rc")
}
editor_pattern='^[[:space:]]*(export[[:space:]]+)?EDITOR='
# Order matters. Single quotes: written literally, expanded when the shell starts.
# shellcheck disable=SC2016
case "$login_shell" in
  bash)
    # ble.sh, then Atuin (which hooks into it), Starship, zoxide (its docs want it near the end),
    # then ble-attach. zoxide goes above an existing ble-attach line.
    rc_add "$shell_rc" "$editor_pattern" 'export EDITOR=nvim VISUAL=nvim'
    rc_add "$shell_rc" 'blesh/ble\.sh' \
      '[[ $- == *i* && -f "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" ]] && source -- "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" --attach=none'
    rc_add "$shell_rc" 'atuin init bash' 'eval "$(atuin init bash)"'
    rc_add "$shell_rc" 'starship init bash' 'eval "$(starship init bash)"'
    rc_add_before "$shell_rc" 'zoxide init' 'eval "$(zoxide init bash)"' 'ble-attach'
    rc_add "$shell_rc" 'ble-attach' '[[ ! ${BLE_VERSION-} ]] || ble-attach'
    ;;
  zsh)
    # Completion, suggestions, Atuin (which feeds them), Starship, zoxide (after compinit),
    # and syntax highlighting last, as its docs require.
    rc_add "$shell_rc" "$editor_pattern" 'export EDITOR=nvim VISUAL=nvim'
    rc_add "$shell_rc" 'compinit' 'autoload -Uz compinit && compinit'
    rc_add "$shell_rc" 'menu select' "zstyle ':completion:*' menu select"
    rc_add "$shell_rc" 'zsh-autosuggestions\.zsh' \
      '[[ -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"'
    rc_add "$shell_rc" 'atuin init zsh' 'eval "$(atuin init zsh)"'
    rc_add "$shell_rc" 'starship init zsh' 'eval "$(starship init zsh)"'
    rc_add_before "$shell_rc" 'zoxide init' 'eval "$(zoxide init zsh)"' 'zsh-syntax-highlighting\.zsh'
    rc_add "$shell_rc" 'zsh-syntax-highlighting\.zsh' \
      '[[ -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"'
    ;;
esac
ok
