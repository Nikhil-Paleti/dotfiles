# Rust via rustup, the official per-user installer, or updated when rustup manages it. A Rust
# that rustup doesn't manage (Homebrew's rust, apt's cargo) is reused as is: rustup warns
# against installing beside one. Then cargo's bin goes on PATH for future shells.
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
step Rust
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
case "$cargo_home" in /*) ;; *) die 'CARGO_HOME must be an absolute path.' ;; esac
cargo_on_path() { case ":$PATH:" in *":$cargo_home/bin:"*) ;; *) export PATH="$cargo_home/bin:$PATH" ;; esac; }
# A rustup from an earlier run that this shell hasn't loaded yet.
[[ ! -d "$cargo_home/bin" ]] || cargo_on_path
rust_note=''
if have rustup; then
  # Only rustup-init's rustup can update itself; Homebrew's and apt's cannot.
  if [[ "$(command -v rustup)" == "$cargo_home/bin/rustup" ]]; then run rustup self update; fi
  # A rustup with no toolchain (Homebrew's starts that way) gets stable as default.
  if [[ "$(rustup toolchain list)" == 'no installed toolchains' ]] || ! rustup default >/dev/null 2>&1; then
    run rustup default stable
  else
    run rustup update --no-self-update
  fi
elif have cargo || have rustc; then
  rust_path=$(command -v cargo || command -v rustc)
  have cargo || die "rustc is installed without cargo or rustup ($rust_path)." \
    'Install cargo with the same package manager, or remove that rustc so rustup can install both; then rerun.'
  if have brew && brew list --formula --versions rust >/dev/null 2>&1; then
    rust_note="Homebrew's rust, not upgraded"
    detail 'To switch to rustup: brew uninstall rust, then rerun bash install.sh.'
  else
    rust_note="not from rustup ($rust_path), not upgraded"
    detail 'To switch to rustup, remove that install, then rerun bash install.sh.'
  fi
else
  rustup_init="$_dotfiles_download_dir/rustup-init.sh"
  # What sh.rustup.rs serves, from rustup's own release host. Startup files are handled below.
  curl --proto '=https' --tlsv1.2 -fsSL https://static.rust-lang.org/rustup/rustup-init.sh -o "$rustup_init"
  run sh "$rustup_init" -y --no-modify-path --profile default --default-toolchain stable </dev/null
  cargo_on_path
  rust_note=installed
fi
have cargo || die 'cargo is not on PATH after the rustup install; check rustup show, then rerun.'
detail "Using $(cargo --version) at $(command -v cargo)."
# rust-analyzer for Neovim's Rust extra. Without the component, rustup's shim is on PATH but
# only errors, so Neovim would find it and fail to start it.
if have rustup; then
  rust_toolchain=$(rustup default)
  run rustup component add rust-analyzer --toolchain "${rust_toolchain%% *}" ||
    warn "Could not add rust-analyzer to ${rust_toolchain%% *}; Neovim's Rust support needs it."
fi
if ! rust-analyzer --version >/dev/null 2>&1; then
  if have rustup; then
    warn 'rust-analyzer does not run; check rustup component list --installed, then rerun.'
  else
    warn 'rust-analyzer is not installed; Neovim needs it for Rust files.' \
      'Install it with the package manager that installed Rust (Homebrew: brew install rust-analyzer).'
  fi
fi
# cargo install puts tools in cargo's bin, so it goes first on PATH, as rustup's own setup does.
# Skipped if a startup file already loads rustup's env file or names that folder.
cargo_checked=("$shell_rc")
[[ "$login_shell" != zsh ]] || cargo_checked=("${ZDOTDIR:-$HOME}/.zshenv" "$shell_rc")
if cargo_found=$(grep -Els '\.cargo/(env|bin)' "${cargo_checked[@]}" || true); [[ -n "$cargo_found" ]]; then
  detail "${cargo_found%%$'\n'*} already sets up cargo's PATH."
else
  # shellcheck disable=SC2016 # written literally; expands when the shell starts
  rc_add "$shell_rc" '^# Cargo tools on PATH \(added by dotfiles install\.sh\)$' \
    'case ":$PATH:" in *":${CARGO_HOME:-$HOME/.cargo}/bin:"*) ;; *) export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH" ;; esac' \
    '# Cargo tools on PATH (added by dotfiles install.sh)'
fi
cargo_version=$(cargo --version)
ok "${cargo_version%% (*}${rust_note:+, $rust_note}"
