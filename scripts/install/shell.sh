# Shell extras: Atuin (history search), Starship (prompt), and suggestions plus syntax
# highlighting: ble.sh for bash, zsh-autosuggestions and zsh-syntax-highlighting for zsh.
# Their startup lines are added to ~/.bashrc or ~/.zshrc only when missing.
install_tool "Atuin" atuin
install_tool "Starship" starship

##### ble.sh install #####
# bash only: ble.sh is a bash line editor, so zsh users skip it. Not in Homebrew; the author
# recommends the nightly build over the old tagged releases.
block_start ble.sh
blesh_dir="${XDG_DATA_HOME:-$HOME/.local/share}/blesh"
if [[ "${SHELL##*/}" != bash ]]; then
  echo "Login shell is ${SHELL##*/}, not bash; skipped."
elif [[ -f "$blesh_dir/ble.sh" ]]; then
  # Quiet unless it fails: the updater prints download progress.
  if bash "$blesh_dir/ble.sh" --update </dev/null >"$_dotfiles_download_dir/blesh-update.log" 2>&1; then
    echo "Updated (or already current): $(bash "$blesh_dir/ble.sh" --version | head -n 1)"
  else
    cat "$_dotfiles_download_dir/blesh-update.log" >&2
    echo 'ble.sh update failed.' >&2
    exit 1
  fi
else
  curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
    -o "$_dotfiles_download_dir/ble-nightly.tar.xz"
  tar -xJf "$_dotfiles_download_dir/ble-nightly.tar.xz" -C "$_dotfiles_download_dir"
  bash "$_dotfiles_download_dir/ble-nightly/ble.sh" --install "$(dirname "$blesh_dir")"
fi
block_end ble.sh
##### end ble.sh install #####

##### zsh plugins install #####
# zsh only: suggestions as you type (Atuin's zsh init makes them come from Atuin) and syntax
# highlighting, the zsh equivalents of ble.sh. Homebrew formulas without a command, so they
# are installed and upgraded here rather than through the tool list.
block_start "zsh plugins"
if [[ "${SHELL##*/}" != zsh ]]; then
  echo "Login shell is ${SHELL##*/}, not zsh; skipped."
else
  for formula in zsh-autosuggestions zsh-syntax-highlighting; do
    if brew list --formula --versions "$formula" >/dev/null 2>&1; then
      brew upgrade --formula "$formula"
    else
      brew install "$formula"
    fi
  done
fi
block_end "zsh plugins"
##### end zsh plugins install #####

##### Shell config #####
block_start "Shell config"
# Atuin's config: the repo copy replaces the installed one.
atuin_config_dir="${ATUIN_CONFIG_DIR:-$HOME/.atuin}"
mkdir -p "$atuin_config_dir"
cp "$DOTFILES_ROOT/config/atuin/config.toml" "$atuin_config_dir/config.toml"
echo "Atuin config applied: $atuin_config_dir/config.toml"

# Starship's config: the repo copy replaces the installed one.
starship_config="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"
mkdir -p "$(dirname "$starship_config")"
cp "$DOTFILES_ROOT/config/starship/starship.toml" "$starship_config"
echo "Starship config applied: $starship_config"

# Shell startup lines: each is appended to ~/.bashrc or ~/.zshrc only if that file doesn't
# already have it. Nothing else in the rc file is touched.
add_rc_line() {
  local rc="$1" pattern="$2" line="$3"
  if grep -Eq "$pattern" "$rc" 2>/dev/null; then
    echo "Already in $rc: $line"
  else
    mkdir -p "$(dirname "$rc")"
    printf '\n# Added by dotfiles install.sh\n%s\n' "$line" >> "$rc"
    echo "Added to $rc: $line"
  fi
}
# Single quotes: written literally, expanded when the shell starts.
# shellcheck disable=SC2016
case "${SHELL##*/}" in
  bash)
    # Order matters: load ble.sh, then Atuin (which hooks into ble.sh) and Starship, then switch
    # ble.sh on. (Starship added after an existing ble-attach line still works, but each new
    # terminal's first prompt is the plain one.)
    add_rc_line "$HOME/.bashrc" 'blesh/ble\.sh' \
      '[[ $- == *i* && -f "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" ]] && source -- "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" --attach=none'
    add_rc_line "$HOME/.bashrc" 'atuin init bash' 'eval "$(atuin init bash)"'
    add_rc_line "$HOME/.bashrc" 'starship init bash' 'eval "$(starship init bash)"'
    add_rc_line "$HOME/.bashrc" 'ble-attach' '[[ ! ${BLE_VERSION-} ]] || ble-attach'
    ;;
  zsh)
    zshrc="${ZDOTDIR:-$HOME}/.zshrc"
    # Order matters: completion setup, suggestions, Atuin (which points suggestions at its
    # history), Starship, and syntax highlighting last, as its docs require.
    add_rc_line "$zshrc" 'compinit' 'autoload -Uz compinit && compinit'
    add_rc_line "$zshrc" "menu select" "zstyle ':completion:*' menu select"
    add_rc_line "$zshrc" 'zsh-autosuggestions\.zsh' \
      '[[ -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"'
    add_rc_line "$zshrc" 'atuin init zsh' 'eval "$(atuin init zsh)"'
    add_rc_line "$zshrc" 'starship init zsh' 'eval "$(starship init zsh)"'
    add_rc_line "$zshrc" 'zsh-syntax-highlighting\.zsh' \
      '[[ -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"'
    ;;
  *) echo 'Shell setup supports bash and zsh.' >&2; exit 1 ;;
esac
block_end "Shell config"
##### end Shell config #####
