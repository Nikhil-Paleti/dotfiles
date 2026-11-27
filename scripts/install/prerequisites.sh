# System build dependencies; sudo is asked for only when something is missing.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
step 'Build prerequisites'
if [[ "$os" == Darwin ]]; then
  if ! xcode-select -p >/dev/null 2>&1 || ! have cc || ! have make; then
    die 'Apple command-line tools are missing. Run xcode-select --install, finish its dialog, then rerun.'
  fi
  ok
else
  deps=()
  for pair in cc:build-essential make:build-essential g++:build-essential curl:curl file:file git:git ps:procps unzip:unzip xz:xz-utils; do
    have "${pair%%:*}" || deps+=("${pair#*:}")
  done
  # marksman (Neovim's markdown server) crashes without ICU; its package name carries the
  # version (libicu78), so take the newest. grep reads all input so ldconfig survives pipefail.
  if have ldconfig && ! ldconfig -p | grep 'libicuuc\.so' >/dev/null; then
    icu=$(apt-cache search --names-only '^libicu[0-9]+$' 2>/dev/null | awk '{print $1}' | sort -V | tail -n 1 || true)
    if [[ -n "$icu" ]]; then deps+=("$icu"); fi
  fi
  if [[ ${#deps[@]} -gt 0 ]]; then
    have apt-get || die 'apt-get is required for missing Debian/Ubuntu build dependencies.'
    have sudo || die 'sudo is required for missing Linux bootstrap packages.'
    note "Installing ${deps[*]} with apt; sudo may ask for your password."
    run sudo apt-get update
    run sudo apt-get install -y "${deps[@]}" ca-certificates
    ok "installed ${deps[*]}"
  else
    ok
  fi
fi
