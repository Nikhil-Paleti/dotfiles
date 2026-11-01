# Report availability; installation and updates use the same component list.
missing=0
printf '%-24s %s\n' COMPONENT STATUS
for item in "${requirements[@]}"; do
  cmd=${item%%:*}
  if have "$cmd"; then
    printf '%-24s present\n' "$cmd"
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
brew_prefix=''
if have brew; then
  brew_prefix=$(brew --prefix)
fi
for formula in "${shell_plugins[@]}"; do
  if [[ -n "$brew_prefix" && -d "$brew_prefix/share/$formula" ]]; then
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
