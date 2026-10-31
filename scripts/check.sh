# command:Homebrew formula. Skip any usable command from another manager too.
requirements=(git:git curl:curl tmux:tmux nvim:neovim rg:ripgrep fd:fd
  lazygit:lazygit fzf:fzf tree-sitter:tree-sitter python3:python node:node
  npm:node zsh:zsh stylua:stylua shfmt:shfmt shellcheck:shellcheck)
missing=0
printf '%-24s %s\n' COMPONENT STATUS
for item in "${requirements[@]}"; do
  cmd=${item%%:*}
  if have "$cmd"; then
    if version_ok "$cmd"; then
      printf '%-24s present\n' "$cmd"
    else
      printf '%-24s incompatible-version\n' "$cmd"; missing=1
    fi
  else
    printf '%-24s missing\n' "$cmd"; missing=1
  fi
done
for cmd in cc make; do
  if have "$cmd"; then printf '%-24s present\n' "$cmd"; else printf '%-24s missing\n' "$cmd"; missing=1; fi
done
config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
if [[ -e "$config" || -L "$config" ]]; then
  printf '%-24s existing-config-preserved\n' LazyVim
else
  printf '%-24s missing-starter\n' LazyVim; missing=1
fi
for formula in zsh-autosuggestions zsh-completions zsh-syntax-highlighting; do
  if have brew && [[ -d "$(brew --prefix)/share/$formula" ]]; then
    printf '%-24s present\n' "$formula"
  else
    printf '%-24s missing\n' "$formula"; missing=1
  fi
done
if [[ "$mode" == check ]]; then
  echo 'Check only. No changes made. Run with --install to provision missing components.'
  echo 'Existing Neovim config is not inspected/executed; plugin health is not verified.'
  exit "$missing"
fi
