# Install Rust and cargo with rustup, the official per-user installer (no sudo), or update
# them when rustup already manages them. A Rust install that rustup does not manage (Homebrew's
# rust formula, apt's cargo) is reused, not upgraded or replaced: rustup refuses to install
# beside one. Then put cargo's bin directory on PATH for future bash and zsh sessions.
##### Rust install #####
block_start Rust
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
case "$cargo_home" in /*) ;; *) echo 'CARGO_HOME must be an absolute path.' >&2; exit 1 ;; esac
# Find a rustup install from an earlier run even if this shell has not loaded it yet.
if [[ -d "$cargo_home/bin" ]]; then
  case ":$PATH:" in *":$cargo_home/bin:"*) ;; *) export PATH="$cargo_home/bin:$PATH" ;; esac
fi
if have rustup; then
  # Only a rustup that rustup-init installed can update itself; Homebrew's and apt's cannot.
  if [[ "$(command -v rustup)" == "$cargo_home/bin/rustup" ]]; then rustup self update; fi
  if rustup default >/dev/null 2>&1; then
    rustup update --no-self-update
  else
    rustup default stable
  fi
elif have cargo || have rustc; then
  rust_path=$(command -v cargo || command -v rustc)
  if have brew && brew list --formula --versions rust >/dev/null 2>&1; then
    echo "Rust from Homebrew's rust formula is installed ($rust_path); reused, not upgraded."
    echo 'To switch to rustup: brew uninstall rust, then rerun bash install.sh.'
  else
    echo "Rust is installed without rustup ($rust_path); reused, not upgraded."
    echo 'To switch to rustup, remove that install, then rerun bash install.sh.'
  fi
else
  # shellcheck disable=SC2154 # _dotfiles_download_dir is set by scripts/lib/temp.sh
  rustup_init="$_dotfiles_download_dir/rustup-init.sh"
  # The script sh.rustup.rs serves, fetched from rustup's own release host.
  curl --proto '=https' --tlsv1.2 -fsSL https://static.rust-lang.org/rustup/rustup-init.sh -o "$rustup_init"
  # Startup files are handled below, the same way as Mason's, so rustup leaves them alone.
  sh "$rustup_init" -y --no-modify-path --profile default --default-toolchain stable </dev/null
  case ":$PATH:" in *":$cargo_home/bin:"*) ;; *) export PATH="$cargo_home/bin:$PATH" ;; esac
fi
have cargo || { echo 'cargo is not on PATH after the Rust step; check rustup show, then rerun.' >&2; exit 1; }
echo "Using $(cargo --version) at $(command -v cargo)."
block_end Rust
##### end Rust install #####

##### Cargo PATH setup #####
# cargo install puts tools in cargo's bin directory with any Rust install, so it goes first on
# PATH, as rustup's own setup does. Safe to rerun: the startup line is added once, and the line
# itself never adds the directory to PATH twice. Skipped if a startup file already loads
# rustup's env file or names the directory (as rustup's default setup does).
printf '\n##### Cargo PATH setup #####\n'
cargo_marker='# Cargo tools on PATH (added by dotfiles install.sh)'
# Single quotes: the line is written literally and expands when the shell starts.
# shellcheck disable=SC2016
cargo_line='case ":$PATH:" in *":${CARGO_HOME:-$HOME/.cargo}/bin:"*) ;; *) export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH" ;; esac'
case "${SHELL##*/}" in
  zsh) cargo_rc="${ZDOTDIR:-$HOME}/.zshrc"; cargo_checked=("${ZDOTDIR:-$HOME}/.zshenv" "$cargo_rc") ;;
  bash) cargo_rc="$HOME/.bashrc"; cargo_checked=("$cargo_rc") ;;
  *) echo 'Automatic cargo PATH setup supports bash and zsh.' >&2; exit 1 ;;
esac
if grep -Fqx "$cargo_marker" "$cargo_rc" 2>/dev/null; then
  echo "Already configured in $cargo_rc; skipped."
elif cargo_found=$(grep -Els '\.cargo/(env|bin)' "${cargo_checked[@]}" || true); [[ -n "$cargo_found" ]]; then
  echo "${cargo_found%%$'\n'*} already sets up cargo's PATH; skipped."
else
  mkdir -p "$(dirname "$cargo_rc")"
  printf '\n%s\n%s\n' "$cargo_marker" "$cargo_line" >> "$cargo_rc"
  echo "Added cargo's bin directory to PATH in $cargo_rc."
fi
printf '##### end Cargo PATH setup #####\n'
##### end Cargo PATH setup #####
