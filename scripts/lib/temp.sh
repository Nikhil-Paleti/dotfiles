# Never consume inherited temporary-path variables. Cleanup is limited to
# directories allocated here and bearing this process's ownership marker.
_dotfiles_download_dir=''
_dotfiles_stage_dir=''
readonly _dotfiles_cleanup_owner="$$:$RANDOM:$RANDOM"
_dotfiles_remove_owned() {
  local owned_dir="$1"
  if [[ -n "$owned_dir" && -d "$owned_dir" && ! -L "$owned_dir" &&
        -f "$owned_dir/.dotfiles-installer-owner" && ! -L "$owned_dir/.dotfiles-installer-owner" ]] &&
     [[ "$(cat "$owned_dir/.dotfiles-installer-owner")" == "$_dotfiles_cleanup_owner" ]]; then
    rm -rf -- "$owned_dir"
  fi
  return 0
}
_dotfiles_cleanup() {
  local saved_status=$?
  trap - EXIT
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
