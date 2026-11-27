# Temp dirs this run owns. Cleanup removes only dirs carrying this run's owner marker, never
# paths taken from inherited variables.
_dotfiles_download_dir=''
_dotfiles_stage_dir=''
readonly _dotfiles_cleanup_owner="$$:$RANDOM:$RANDOM"
_dotfiles_remove_owned() {
  local owned_dir="$1"
  if [[ -n "$owned_dir" && -d "$owned_dir" && ! -L "$owned_dir" &&
        -f "$owned_dir/.dotfiles-installer-owner" && ! -L "$owned_dir/.dotfiles-installer-owner" ]] &&
     [[ "$(cat "$owned_dir/.dotfiles-installer-owner")" == "$_dotfiles_cleanup_owner" ]]; then
    rm -rf -- "$owned_dir" || echo "Could not remove temporary directory: $owned_dir" >&2
  fi
  return 0
}
_dotfiles_cleanup() {
  local saved_status=$?
  trap - EXIT
  if [[ $saved_status -ne 0 && -n "$_dotfiles_step" ]]; then
    _dotfiles_clear
    printf "✗ %s failed.%s\n" "$_dotfiles_step" "$(verbose || printf " Rerun with --verbose for all output.")" >&2
  fi
  _dotfiles_remove_owned "$_dotfiles_download_dir"
  _dotfiles_remove_owned "$_dotfiles_stage_dir"
  exit "$saved_status"
}
trap _dotfiles_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
_dotfiles_download_dir=$(mktemp -d)
readonly _dotfiles_download_dir
printf '%s\n' "$_dotfiles_cleanup_owner" > "$_dotfiles_download_dir/.dotfiles-installer-owner"
# shellcheck disable=SC2034 # used by run in scripts/lib/common.sh
_dotfiles_log="$_dotfiles_download_dir/step.log"
