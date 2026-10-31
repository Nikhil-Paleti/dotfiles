##### zsh install #####
install_tool "zsh" zsh zsh
##### end zsh install #####

##### zsh-autosuggestions install #####
block_start zsh-autosuggestions
if [[ -d "$(brew --prefix)/share/zsh-autosuggestions" ]]; then
  echo 'Already present; skipped.'
else
  brew install zsh-autosuggestions
fi
block_end zsh-autosuggestions
##### end zsh-autosuggestions install #####

##### zsh-completions install #####
block_start zsh-completions
if [[ -d "$(brew --prefix)/share/zsh-completions" ]]; then
  echo 'Already present; skipped.'
else
  brew install zsh-completions
fi
block_end zsh-completions
##### end zsh-completions install #####

##### zsh-syntax-highlighting install #####
block_start zsh-syntax-highlighting
if [[ -d "$(brew --prefix)/share/zsh-syntax-highlighting" ]]; then
  echo 'Already present; skipped.'
else
  brew install zsh-syntax-highlighting
fi
block_end zsh-syntax-highlighting
##### end zsh-syntax-highlighting install #####
