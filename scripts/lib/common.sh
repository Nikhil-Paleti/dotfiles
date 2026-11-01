# Shared command checks and component output.
have() { command -v "$1" >/dev/null 2>&1; }
block_start() { printf '\n##### %s install #####\n' "$1"; }
block_end() { printf '##### end %s install #####\n' "$1"; }
install_tool() {
  local label="$1" command_name="$2" formula_name="$3"
  block_start "$label"
  if have "$command_name"; then
    echo 'Already present; skipped.'
  else
    brew install "$formula_name"
    have "$command_name" || { echo "$command_name is not on PATH after install; resolve package-manager conflicts and retry." >&2; exit 1; }
  fi
  block_end "$label"
}
