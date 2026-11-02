# Install Homebrew as the current user, allowing its normal setup prompts.
##### Homebrew install #####
printf '\n##### Homebrew install #####\n'
if ! have brew; then
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$_dotfiles_download_dir/homebrew.sh"
  /bin/bash "$_dotfiles_download_dir/homebrew.sh"
  for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [[ -x "$prefix/bin/brew" ]]; then export PATH="$prefix/bin:$prefix/sbin:$PATH"; break; fi
  done
fi
have brew || { echo 'Homebrew unavailable after installation.' >&2; exit 1; }
printf '##### end Homebrew install #####\n'
##### end Homebrew install #####
