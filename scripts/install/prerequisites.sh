# Install missing system build dependencies, requesting sudo only when needed.
##### Build prerequisites install #####
printf '\n##### Build prerequisites install #####\n'
if [[ "$os" == Darwin ]]; then
  if ! xcode-select -p >/dev/null 2>&1 || ! have cc || ! have make; then
    echo 'Installing Apple command-line tools requires its GUI. Run xcode-select --install, finish, then rerun.' >&2
    exit 1
  fi
else
  deps=()
  for pair in cc:build-essential make:build-essential g++:build-essential curl:curl file:file git:git ps:procps unzip:unzip; do
    have "${pair%%:*}" || deps+=("${pair#*:}")
  done
  # marksman (Neovim's markdown language server) is a .NET app and crashes without ICU.
  # The package name carries the ICU version (libicu78 on Ubuntu 26.04), so pick the newest.
  # grep reads all input (no -q): an early exit would fail ldconfig under pipefail.
  if have ldconfig && ! ldconfig -p | grep 'libicuuc\.so' >/dev/null; then
    icu=$(apt-cache search --names-only '^libicu[0-9]+$' 2>/dev/null | awk '{print $1}' | sort -V | tail -n 1 || true)
    if [[ -n "$icu" ]]; then deps+=("$icu"); fi
  fi
  if [[ ${#deps[@]} -gt 0 ]]; then
    have apt-get || { echo 'apt-get is required for missing Debian/Ubuntu build dependencies.' >&2; exit 1; }
    have sudo || { echo 'sudo is required for missing Linux bootstrap packages.' >&2; exit 1; }
    echo 'System build dependencies are missing; sudo may request your password.'
    sudo apt-get update
    sudo apt-get install -y "${deps[@]}" ca-certificates
  fi
fi
printf '##### end Build prerequisites install #####\n'
##### end Build prerequisites install #####
