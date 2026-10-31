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
# Discover standard installations without writing shell startup files.
if ! command -v brew >/dev/null 2>&1; then
for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
  if [[ -x "$prefix/bin/brew" ]]; then
    export PATH="$prefix/bin:$prefix/sbin:$PATH"
    break
  fi
done
fi
# Reuse tools already installed by Mason instead of installing duplicate copies.
mason_bin="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin"
[[ ! -d "$mason_bin" ]] || export PATH="$PATH:$mason_bin"
