# Platform validation only. This module installs nothing and writes no files.
# Intended to be sourced by the future Bash entry point.
[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo 'Run without sudo as your normal user; only system setup steps request elevated privileges.' >&2; exit 1; }
os=$(uname -s)
case "$os" in
  Darwin) ;;
  Linux)
    [[ -r /etc/os-release ]] || { echo 'Cannot identify Linux distribution.' >&2; exit 1; }
    . /etc/os-release
    supported_linux=false
    for family in ${ID:-} ${ID_LIKE:-}; do
      case "$family" in ubuntu|debian) supported_linux=true ;; esac
    done
    [[ "$supported_linux" == true ]] || { echo 'Supported: Debian/Ubuntu Linux.' >&2; exit 1; }
    # WSL1 lacks the supported Linux runtime; ordinary Linux is unaffected.
    kernel_release=$(uname -r)
    case "$kernel_release" in
      *[Mm]icrosoft*)
        case "$kernel_release" in *WSL2*|*wsl2*) ;; *) echo 'Use WSL2 rather than WSL1.' >&2; exit 1 ;; esac ;;
    esac ;;
  *) echo 'Supported: macOS and Debian/Ubuntu Linux/WSL2; not native Windows.' >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64|x86_64) ;;
  *) echo 'Supported architectures: ARM64 and x86_64.' >&2; exit 1 ;;
esac
# XDG paths must be absolute. Reject ambiguous destinations before any writes.
for xdg_path in "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_DATA_HOME:-$HOME/.local/share}" "${ZDOTDIR:-$HOME}"; do
  case "$xdg_path" in /*) ;; *) echo 'XDG config/data paths and ZDOTDIR must be absolute.' >&2; exit 1 ;; esac
done
# Do not follow a user-managed zshrc symlink or overwrite a non-file.
zshrc="${ZDOTDIR:-$HOME}/.zshrc"
[[ ! -L "$zshrc" && ( ! -e "$zshrc" || -f "$zshrc" ) ]] || {
  echo "Keep your existing $zshrc; use a regular file or integrate config/zsh/zshrc manually." >&2; exit 1;
}
