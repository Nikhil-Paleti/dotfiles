# Shared command checks, version checks and component output.
have() { command -v "$1" >/dev/null 2>&1; }
# Compare numeric versions without requiring Python/Node to be installed first.
at_least() {
  awk -v actual="$1" -v required="$2" 'BEGIN {
    split(actual,a,"."); split(required,r,".");
    for(i=1;i<=3;i++){if(a[i]+0>r[i]+0)exit 0;if(a[i]+0<r[i]+0)exit 1}exit 0
  }'
}
version_ok() {
  case "$1" in
    nvim) at_least "$(nvim --version | awk 'NR==1 {sub(/^v/,"",$2); print $2}')" 0.11.2 ;;
    git) at_least "$(git --version | awk '{print $3}')" 2.19.0 ;;
    *) return 0 ;;
  esac
}
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
