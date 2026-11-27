# Find tools that are installed but not loaded in this shell, without touching startup files.
load_brew
# Reuse tools Mason already installed instead of installing second copies.
mason_bin="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin"
[[ ! -d "$mason_bin" ]] || export PATH="$PATH:$mason_bin"
