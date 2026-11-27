# Checks only: supported OS, architecture, shell and paths. Installs and writes nothing.
# shellcheck disable=SC2034 # os, kernel_release, login_shell, shell_rc are read by later files
[[ ${EUID:-$(id -u)} -ne 0 ]] || die 'Run without sudo as your normal user; only system setup steps request elevated privileges.'
os=$(uname -s)
case "$os" in
  Darwin) ;;
  Linux)
    [[ -r /etc/os-release ]] || die 'Cannot identify Linux distribution.'
    . /etc/os-release
    supported_linux=false
    for family in ${ID:-} ${ID_LIKE:-}; do
      case "$family" in ubuntu|debian) supported_linux=true ;; esac
    done
    [[ "$supported_linux" == true ]] || die 'Supported: Debian/Ubuntu Linux.'
    kernel_release=$(uname -r)
    case "$kernel_release" in
      *[Mm]icrosoft*) case "$kernel_release" in *WSL2*|*wsl2*) ;; *) die 'Use WSL2 rather than WSL1.' ;; esac ;;
    esac ;;
  *) die 'Supported: macOS and Debian/Ubuntu Linux/WSL2; not native Windows.' ;;
esac
case "$(uname -m)" in
  arm64|aarch64|x86_64) ;;
  *) die 'Supported architectures: ARM64 and x86_64.' ;;
esac
for xdg_path in "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_DATA_HOME:-$HOME/.local/share}"; do
  case "$xdg_path" in /*) ;; *) die 'XDG config/data paths must be absolute.' ;; esac
done
# Startup files the installer adds lines to.
login_shell=${SHELL##*/}
case "$login_shell" in
  zsh) shell_rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
  bash) shell_rc="$HOME/.bashrc" ;;
  *) die "Shell setup supports bash and zsh, not $login_shell (from SHELL)." ;;
esac
