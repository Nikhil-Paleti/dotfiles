# Update installed Homebrew formulae from this project's tool list.
# The normal install steps that follow provide any missing tools.
# Do not upgrade unrelated formulae or run user config.
brew update
# A broken package database is an error, not a list of missing tools.
brew list --formula >/dev/null
updated_formulae=':' 
for item in "${requirements[@]}"; do
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
echo 'Package update complete. Installing missing tools next.'
