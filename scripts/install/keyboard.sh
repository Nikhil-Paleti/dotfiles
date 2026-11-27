# Keyboard layer (config/kanata/kanata.kbd), run by Kanata on the Mac and Windows. Linux machines
# are reached over SSH and need nothing.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
step 'Keyboard layer'
kanata_src="$DOTFILES_ROOT/config/kanata/kanata.kbd"
case "$os" in
  Darwin) source "$DOTFILES_ROOT/scripts/install/keyboard-macos.sh" ;;
  Linux)
    case "$kernel_release" in
      *[Mm]icrosoft*) source "$DOTFILES_ROOT/scripts/install/keyboard-wsl.sh" ;;
      *) skip 'Kanata runs on the Mac or Windows machine with the keyboard' ;;
    esac
    ;;
esac
