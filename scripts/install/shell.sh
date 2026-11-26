# Shell extras: Atuin (history search) and ble.sh (bash only: suggestions and highlighting).
# Their startup lines are added to ~/.bashrc or ~/.zshrc only when missing.
install_tool "Atuin" atuin

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

##### Shell config #####
block_start "Shell config"
# Atuin's config: the repo copy replaces the installed one.
atuin_config_dir="${ATUIN_CONFIG_DIR:-$HOME/.atuin}"
mkdir -p "$atuin_config_dir"
cp "$DOTFILES_ROOT/config/atuin/config.toml" "$atuin_config_dir/config.toml"
echo "Atuin config applied: $atuin_config_dir/config.toml"

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
    # Order matters: load ble.sh, then Atuin (which hooks into ble.sh), then switch ble.sh on.
    add_rc_line "$HOME/.bashrc" 'blesh/ble\.sh' \
      '[[ $- == *i* && -f "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" ]] && source -- "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" --attach=none'
    add_rc_line "$HOME/.bashrc" 'atuin init bash' 'eval "$(atuin init bash)"'
    add_rc_line "$HOME/.bashrc" 'ble-attach' '[[ ! ${BLE_VERSION-} ]] || ble-attach'
    ;;
  zsh) add_rc_line "${ZDOTDIR:-$HOME}/.zshrc" 'atuin init zsh' 'eval "$(atuin init zsh)"' ;;
  *) echo 'Shell setup supports bash and zsh.' >&2; exit 1 ;;
esac
block_end "Shell config"
##### end Shell config #####
