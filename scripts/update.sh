# Upgrade the Homebrew formulas in this project's tool list (nothing else); later steps install
# what is missing.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
step 'Homebrew update'
run brew update
# A broken package database is an error, not a list of missing tools.
run brew list --formula
updated_formulae=':' upgraded=()
for item in "${requirements[@]}"; do
  formula=${item#*:}
  # node and npm share a formula.
  case "$updated_formulae" in *":$formula:"*) continue ;; esac
  updated_formulae="$updated_formulae$formula:"
  if ! brew list --formula --versions "$formula" >/dev/null 2>&1; then
    detail "$formula: not installed with Homebrew; skipped."
    continue
  fi
  run brew upgrade --formula "$formula"
  # brew says "already installed" when there was nothing to upgrade.
  verbose || grep -q 'already installed' "$_dotfiles_log" || upgraded+=("$formula")
done
ok "${upgraded[*]:+upgraded ${upgraded[*]}}"
