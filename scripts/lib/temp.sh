# This run's temp folders, removed when it exits (also on failure or Ctrl+C).
_dotfiles_download_dir=''
_dotfiles_stage_dir=''
_dotfiles_cleanup() {
  local saved_status=$? dir
  trap - EXIT
  if [[ $saved_status -ne 0 && -n "$_dotfiles_step" ]]; then
    _dotfiles_clear
    printf "✗ %s failed.%s\n" "$_dotfiles_step" "$(verbose || printf " Rerun with --verbose for all output.")" >&2
  fi
  for dir in "$_dotfiles_download_dir" "$_dotfiles_stage_dir"; do
    [[ -z "$dir" || ! -d "$dir" || -L "$dir" ]] || rm -rf -- "$dir" || warn "Could not remove $dir"
  done
  exit "$saved_status"
}
trap _dotfiles_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
_dotfiles_download_dir=$(mktemp -d)
readonly _dotfiles_download_dir
# shellcheck disable=SC2034 # used by run in scripts/lib/common.sh
_dotfiles_log="$_dotfiles_download_dir/step.log"
