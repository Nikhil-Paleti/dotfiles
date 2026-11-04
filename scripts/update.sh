# Update only installed Homebrew formulae from this project's tool list.
# Missing gh and the zsh setup are installed; leave other missing tools alone.
# Do not upgrade unrelated formulae or run user config.
have brew || { echo 'Homebrew not found. Run --install first.' >&2; exit 1; }
export NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1
brew update
# A broken package database is an error, not a list of missing tools.
brew list --formula >/dev/null
updated_formulae=':' 
for item in "${requirements[@]}" "${zsh_plugins[@]}"; do
  formula=${item#*:}
  # Node.js and npm share a formula: process it only once.
  case "$updated_formulae" in *":$formula:"*) continue ;; esac
  updated_formulae="$updated_formulae$formula:"
  printf '\n##### %s update #####\n' "$formula"
  if brew list --formula --versions "$formula" >/dev/null 2>&1; then
    brew upgrade --formula "$formula"
  elif [[ "$formula" == gh ]]; then
    install_tool "GitHub CLI (Octo)" gh
  else
    echo 'Not installed through Homebrew; skipped.'
  fi
  printf '##### end %s update #####\n' "$formula"
done
echo 'Package update complete. Setting up zsh, then applying repo configs.'
echo 'Neovim plugins are installed from the applied config when Neovim starts.'
