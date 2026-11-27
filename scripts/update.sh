# Upgrade the Homebrew formulas in this project's tool list (nothing else), in one brew call;
# later steps install what is missing.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
step 'Homebrew update'
run brew update
# A broken package database is an error, not a list of missing tools.
brew_installed=$(brew list --formula -1) || die 'brew list failed; run brew doctor, then rerun.'
managed=()
for item in "${requirements[@]}"; do
  formula=${item#*:}
  # Only formulas installed with Homebrew (a tool installed another way is left alone), once
  # each (node and npm share a formula).
  grep -qxF -- "$formula" <<<"$brew_installed" || continue
  case " ${managed[*]-} " in *" $formula "*) continue ;; esac
  managed+=("$formula")
done
outdated=()
if [[ ${#managed[@]} -gt 0 ]]; then
  # brew outdated exits 1 when a named formula is outdated; only its list matters here.
  while IFS= read -r formula; do
    [[ -z "$formula" ]] || outdated+=("$formula")
  done < <(brew outdated --formula --quiet "${managed[@]}")
fi
[[ ${#outdated[@]} -eq 0 ]] || run brew upgrade --formula "${outdated[@]}"
ok "${outdated[*]:+upgraded ${outdated[*]}}"
