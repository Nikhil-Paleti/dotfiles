# Bring this dotfiles checkout up to date first, so one `bash install.sh` updates everything.
# Fast-forward only: with local changes, another branch or no network, the run goes on as is.
# Works in a plain git checkout and in a jj repo colocated with git.
# shellcheck disable=SC2154 # dotfiles_args comes from install.sh
[[ "${DOTFILES_PULLED:-0}" != 1 ]] || return 0
step 'Dotfiles repo'
dotfiles_head() { git -C "$DOTFILES_ROOT" rev-parse HEAD 2>/dev/null || true; }
dotfiles_git() { git -C "$DOTFILES_ROOT" "$@"; }
dotfiles_jj() { (cd "$DOTFILES_ROOT" && jj "$@") 2>/dev/null; }
dotfiles_is_jj() { [[ -d "$DOTFILES_ROOT/.jj" ]]; }
# No uncommitted edits: in jj the working copy is empty, in git tracked files are unchanged.
dotfiles_clean() {
  if dotfiles_is_jj; then
    [[ "$(dotfiles_jj log --no-graph -r @ -T 'empty')" == true ]]
  else
    [[ -z "$(dotfiles_git status --porcelain --untracked-files=no 2>/dev/null)" ]]
  fi
}
# Run the checked-out install.sh, so every later step is that version.
dotfiles_rerun() {
  exec env DOTFILES_PULLED=1 bash "$DOTFILES_ROOT/install.sh" ${dotfiles_args[@]+"${dotfiles_args[@]}"}
}
dotfiles_before=$(dotfiles_head)

if ! have git || [[ -z "$dotfiles_before" ]]; then
  skip 'not a git checkout'
elif dotfiles_is_jj; then
  # jj keeps git's HEAD at the working copy's parent. If the working copy is empty and its
  # parent is behind trunk() (main@origin), start a new change on trunk(); the empty one is
  # dropped.
  if ! have jj; then
    skip 'jj repo, but jj is not installed yet'
  elif ! dotfiles_clean; then
    skip 'local changes'
  elif ! dotfiles_jj git fetch --quiet >/dev/null; then
    skip 'could not fetch'
  elif [[ -z "$(dotfiles_jj log --no-graph -r '@- & ::trunk()' -T 'commit_id')" ]]; then
    skip 'working copy is not on main'
  elif [[ -n "$(dotfiles_jj log --no-graph -r '@- & trunk()' -T 'commit_id')" ]]; then
    ok 'up to date'
  else
    dotfiles_jj new --quiet 'trunk()' >/dev/null || die 'jj new trunk() failed in the dotfiles repo.'
    ok "now at $(dotfiles_version)"
  fi
elif ! dotfiles_clean; then
  skip 'local changes'
elif ! dotfiles_git symbolic-ref -q HEAD >/dev/null; then
  skip 'detached HEAD'
elif ! dotfiles_git rev-parse -q --verify '@{upstream}' >/dev/null 2>&1; then
  skip 'branch has no upstream'
elif ! dotfiles_git pull --ff-only --quiet >/dev/null 2>&1; then
  skip 'could not fast-forward'
elif [[ "$(dotfiles_head)" == "$dotfiles_before" ]]; then
  ok 'up to date'
else
  ok "now at $(dotfiles_version)"
fi
# New commits: run the pulled install.sh instead.
[[ "$(dotfiles_head)" == "$dotfiles_before" ]] || dotfiles_rerun
