##### zsh install #####
install_tool "zsh" zsh
##### end zsh install #####

brew_prefix=$(brew --prefix)
for formula in "${shell_plugins[@]}"; do
  block_start "$formula"
  if [[ -d "$brew_prefix/share/$formula" ]]; then
    echo 'Already present; skipped.'
  else
    brew install "$formula"
    [[ -d "$brew_prefix/share/$formula" ]] || { echo "Missing plugin directory after installing $formula" >&2; exit 1; }
  fi
  block_end "$formula"
done
