# Shared helpers. Output is one line per step; --verbose (DOTFILES_VERBOSE=1) shows every
# command's output, and a failing command always shows its own.
#
#   step NAME        start a step (a "· NAME …" line on a terminal)
#   ok [DETAIL]      ✓ NAME (DETAIL)
#   skip REASON      – NAME skipped (REASON)
#   fail REASON      ✗ NAME (REASON) on stderr; the run goes on
#   note TEXT...     a line you should read, always shown
#   warn TEXT...     a problem you should fix, always shown (stderr)
#   detail TEXT...   shown only with --verbose
#   die TEXT...      print to stderr and exit 1
#   run CMD...       run CMD quietly; on failure print its output and return its status
#   run_live CMD...  run CMD with the terminal, for installers that prompt
# shellcheck disable=SC2154 # globals come from files install.sh sources earlier
DOTFILES_VERBOSE=${DOTFILES_VERBOSE:-0}
[[ -t 1 ]] && _dotfiles_tty=1 || _dotfiles_tty=0
_dotfiles_step='' _dotfiles_pending=0
_dotfiles_log=/dev/null # points into the owned temp dir once scripts/lib/temp.sh runs
verbose() { [[ "$DOTFILES_VERBOSE" == 1 ]]; }
have() { command -v "$1" >/dev/null 2>&1; }
# A path with $HOME shown as ~, for messages.
short_path() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
# Erase the "· NAME …" progress line before anything else prints.
_dotfiles_clear() { if ((_dotfiles_pending)); then printf '\r\033[K'; _dotfiles_pending=0; fi; }
step() {
  _dotfiles_clear
  _dotfiles_step=$1
  if verbose; then printf '\n==> %s\n' "$1"
  elif ((_dotfiles_tty)); then printf '· %s …' "$1"; _dotfiles_pending=1
  fi
}
ok() { _dotfiles_clear; printf '✓ %s%s\n' "$_dotfiles_step" "${1:+ ($1)}"; _dotfiles_step=''; }
skip() { _dotfiles_clear; printf '– %s skipped (%s)\n' "$_dotfiles_step" "$1"; _dotfiles_step=''; }
fail() { _dotfiles_clear; printf '✗ %s (%s)\n' "$_dotfiles_step" "$1" >&2; _dotfiles_step=''; }
note() { _dotfiles_clear; printf '  %s\n' "$@"; }
warn() { _dotfiles_clear; printf '! %s\n' "$1" >&2; shift; [[ $# -eq 0 ]] || printf '  %s\n' "$@" >&2; }
detail() { if verbose; then _dotfiles_clear; printf '  %s\n' "$@"; fi; }
die() { _dotfiles_clear; printf '%s\n' "$@" >&2; exit 1; }
run() {
  if verbose; then "$@"; return; fi
  local status=0
  "$@" >"$_dotfiles_log" 2>&1 || status=$?
  if ((status)); then _dotfiles_clear; cat "$_dotfiles_log" >&2; fi
  return "$status"
}
run_live() { _dotfiles_clear; "$@"; }
# Put Homebrew on PATH for this run if it is installed but not loaded.
load_brew() {
  have brew && return
  local prefix
  for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [[ -x "$prefix/bin/brew" ]]; then export PATH="$prefix/bin:$prefix/sbin:$PATH"; return; fi
  done
}

# Install each missing command with Homebrew (formulas from scripts/components.sh).
install_tools() {
  local label=$1 command_name formula item installed=()
  shift
  step "$label"
  for command_name in "$@"; do
    formula=''
    for item in "${requirements[@]}"; do
      if [[ "${item%%:*}" == "$command_name" ]]; then formula=${item#*:}; break; fi
    done
    [[ -n "$formula" ]] || die "Unknown component: $command_name"
    if have "$command_name"; then detail "$command_name: already installed"; continue; fi
    run brew install "$formula"
    have "$command_name" || die "$command_name is not on PATH after brew install $formula; resolve package-manager conflicts and retry."
    installed+=("$command_name")
  done
  ok "${installed[*]:+installed ${installed[*]}}"
}

# Append "MARKER\nLINE" to RC unless grep -E PATTERN already matches in it.
dotfiles_rc_changes=()
rc_add() {
  local rc=$1 pattern=$2 line=$3 marker=${4:-'# Added by dotfiles install.sh'}
  if grep -Eq -- "$pattern" "$rc" 2>/dev/null; then detail "Already in $rc: $line"; return; fi
  mkdir -p "$(dirname "$rc")"
  printf '\n%s\n%s\n' "$marker" "$line" >>"$rc"
  detail "Added to $rc: $line"
  dotfiles_rc_changes+=("$rc")
}
