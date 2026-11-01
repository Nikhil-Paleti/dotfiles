# Update only installed Homebrew formulae from this project's tool list.
# Do not install missing tools, upgrade unrelated formulae, or run user config.
have brew || { echo 'Homebrew not found. Run --install first.' >&2; exit 1; }
export NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1
brew update
updated_formulae=':'
for item in "${requirements[@]}" zsh-autosuggestions:zsh-autosuggestions zsh-completions:zsh-completions zsh-syntax-highlighting:zsh-syntax-highlighting; do
  formula=${item#*:}
  # Node.js and npm share a formula: process it only once.
  case "$updated_formulae" in *":$formula:"*) continue ;; esac
  updated_formulae="$updated_formulae$formula:"
  printf '\n##### %s update #####\n' "$formula"
  if brew list --formula --versions "$formula" >/dev/null 2>&1; then
    brew upgrade --formula "$formula"
  else
    echo 'Not installed through Homebrew; skipped.'
  fi
  printf '##### end %s update #####\n' "$formula"
done
echo 'Update complete. Missing tools, system packages, Mason tools and Neovim plugins were left alone.'
echo 'Manage LazyVim/plugin updates inside Neovim with :Lazy update.'
