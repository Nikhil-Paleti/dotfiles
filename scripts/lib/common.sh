# Sourcing defines helpers only; it does not install anything.
# install_tool expects the future components.sh requirements array to be loaded.
# Shared command checks and component output.
have() { command -v "$1" >/dev/null 2>&1; }
block_start() { printf '\n##### %s install #####\n' "$1"; }
block_end() { printf '##### end %s install #####\n' "$1"; }
install_tool() {
  local label="$1" command_name="$2" formula_name='' item
  for item in "${requirements[@]}"; do
    if [[ "${item%%:*}" == "$command_name" ]]; then formula_name=${item#*:}; break; fi
  done
  [[ -n "$formula_name" ]] || { echo "Unknown component: $command_name" >&2; exit 1; }
  block_start "$label"
  if have "$command_name"; then
    echo 'Already present; skipped.'
  else
    brew install "$formula_name"
    have "$command_name" || { echo "$command_name is not on PATH after install; resolve package-manager conflicts and retry." >&2; exit 1; }
  fi
  block_end "$label"
}
