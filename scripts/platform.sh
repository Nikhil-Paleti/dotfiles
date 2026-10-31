[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo 'Run as your normal user, not root.' >&2; exit 1; }
os=$(uname -s)
case "$os" in
  Darwin) ;;
  Linux)
    [[ -r /etc/os-release ]] || { echo 'Cannot identify Linux distribution.' >&2; exit 1; }
    . /etc/os-release
    case "${ID:-} ${ID_LIKE:-}" in
      *ubuntu*|*debian*) ;;
      *) echo 'Supported: macOS and Debian/Ubuntu Linux (including WSL2).' >&2; exit 1 ;;
    esac ;;
  *) echo 'Supported: macOS and Debian/Ubuntu Linux/WSL2; not native Windows.' >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64|x86_64) ;;
  *) echo 'Supported architectures: ARM64 and x86_64.' >&2; exit 1 ;;
esac
