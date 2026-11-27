# Bring this dotfiles checkout up to date first, so one `bash install.sh` updates everything.
# Fast-forward only: with local changes, another branch or no network, the run goes on as is.
# Works in a plain git checkout and in a jj repo colocated with git.
[[ "${DOTFILES_PULLED:-0}" != 1 ]] || return 0
step 'Dotfiles repo'
dotfiles_head() { git -C "$DOTFILES_ROOT" rev-parse HEAD 2>/dev/null || true; }
dotfiles_jj() { (cd "$DOTFILES_ROOT" && jj "$@") 2>/dev/null; }
dotfiles_before=$(dotfiles_head)
if ! have git || [[ -z "$dotfiles_before" ]]; then
  skip 'not a git checkout'
elif [[ -d "$DOTFILES_ROOT/.jj" ]]; then
  # jj keeps git's HEAD at the working copy's parent. If the working copy is empty and its
  # parent is behind trunk() (main@origin), start a new change on trunk(); the empty one is
  # dropped.
  if ! have jj; then
    skip 'jj repo, but jj is not installed yet'
  elif [[ "$(dotfiles_jj log --no-graph -r @ -T 'empty')" != true ]]; then
    skip 'local changes'
  elif ! dotfiles_jj git fetch --quiet >/dev/null; then
    skip 'could not fetch'
  elif [[ -z "$(dotfiles_jj log --no-graph -r '@- & ::trunk()' -T 'commit_id')" ]]; then
    skip 'working copy is not on main'
  elif [[ -n "$(dotfiles_jj log --no-graph -r '@- & trunk()' -T 'commit_id')" ]]; then
    ok 'up to date'
  else
    dotfiles_jj new --quiet 'trunk()' >/dev/null || die 'jj new trunk() failed in the dotfiles repo.'
    ok "now at $(git -C "$DOTFILES_ROOT" rev-parse --short HEAD)"
  fi
elif [[ -n "$(git -C "$DOTFILES_ROOT" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
  skip 'local changes'
elif ! git -C "$DOTFILES_ROOT" symbolic-ref -q HEAD >/dev/null; then
  skip 'detached HEAD'
elif ! git -C "$DOTFILES_ROOT" rev-parse -q --verify '@{upstream}' >/dev/null 2>&1; then
  skip 'branch has no upstream'
elif ! git -C "$DOTFILES_ROOT" pull --ff-only --quiet >/dev/null 2>&1; then
  skip 'could not fast-forward'
elif [[ "$(dotfiles_head)" == "$dotfiles_before" ]]; then
  ok 'up to date'
else
  ok "now at $(git -C "$DOTFILES_ROOT" rev-parse --short HEAD)"
fi
# New commits: run the pulled install.sh instead, so every later step is the new version.
if [[ "$(dotfiles_head)" != "$dotfiles_before" ]]; then
  exec env DOTFILES_PULLED=1 bash "$DOTFILES_ROOT/install.sh" "$@"
fi
