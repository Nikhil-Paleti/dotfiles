#!/usr/bin/env bash
# Copy the files install.sh writes (shell startup files and tool configs) into $1,
# so CI can compare the first and second runs.
set -euo pipefail
dest="$1"
mkdir -p "$dest"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
for file in .bashrc .profile .bash_profile .bash_login .zshrc .zprofile; do
  [[ ! -f "$HOME/$file" ]] || cp "$HOME/$file" "$dest/${file#.}"
done
cp "${ATUIN_CONFIG_DIR:-$HOME/.atuin}/config.toml" "$dest/atuin.toml"
cp "${STARSHIP_CONFIG:-$config_home/starship.toml}" "$dest/starship.toml"
cp -R "$config_home/nvim" "$dest/nvim"
ls -A "$dest"
