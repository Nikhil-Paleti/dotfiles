# Find existing tools before reporting or installing missing components.
# Discover standard installations without writing shell startup files.
if ! command -v brew >/dev/null 2>&1; then
for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
  if [[ -x "$prefix/bin/brew" ]]; then
    export PATH="$prefix/bin:$prefix/sbin:$PATH"
    break
  fi
done
fi
# Reuse tools already installed by Mason instead of installing duplicate copies.
mason_bin="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin"
[[ ! -d "$mason_bin" ]] || export PATH="$PATH:$mason_bin"
