# Do not let child installers read terminal input. Privilege failures stop the run.
exec </dev/null
# An installed but too-old editor/Git may belong to another manager. Do not
# silently upgrade or replace it; let the owner choose how to resolve it.
for cmd in git nvim; do
  if have "$cmd" && ! version_ok "$cmd"; then
    echo "$cmd is too old; update it using its current package manager, then retry." >&2
    exit 1
  fi
done
