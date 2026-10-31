##### Build prerequisites install #####
printf '\n##### Build prerequisites install #####\n'
if [[ "$os" == Darwin ]]; then
  if ! xcode-select -p >/dev/null 2>&1 || ! have cc || ! have make; then
    echo 'Installing Apple command-line tools requires its GUI. Run xcode-select --install, finish, then rerun.' >&2
    exit 1
  fi
else
  deps=()
  for pair in cc:build-essential make:build-essential g++:build-essential curl:curl file:file git:git ps:procps; do
    have "${pair%%:*}" || deps+=("${pair#*:}")
  done
  if [[ ${#deps[@]} -gt 0 ]]; then
    have sudo || { echo 'sudo is required for missing Linux bootstrap packages.' >&2; exit 1; }
    sudo -n apt-get update
    sudo -n apt-get install -y "${deps[@]}" ca-certificates
  fi
fi
printf '##### end Build prerequisites install #####\n'
##### end Build prerequisites install #####
