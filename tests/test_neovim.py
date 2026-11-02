"""Run with python3 tests/test_neovim.py; all writes stay in temporary homes."""
import os
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
REAL_NVIM = shutil.which('nvim')
entry = (ROOT / 'install.sh').read_text()
assert entry.index('scripts/install/neovim.sh') < entry.index('scripts/install/lazyvim.sh')

with tempfile.TemporaryDirectory(prefix='dotfiles-neovim-') as temporary:
    base = pathlib.Path(temporary)
    for name, compatible, existing, brew_ok in [
        ('old', False, True, True),
        ('no-luajit', False, True, True),
        ('broken-startup', False, True, True),
        ('compatible', True, True, True),
        ('missing-installed', True, False, True),
        ('missing-install-failed', False, False, False),
        ('newly-installed-incompatible', False, False, True),
    ]:
        home = base / name
        bin_dir = home / 'bin'
        bin_dir.mkdir(parents=True)
        config = home / 'config/nvim'
        config.mkdir(parents=True)
        (config / 'sentinel').write_text('keep user config\n')
        backup = home / 'config/nvim_backup'
        backup.mkdir()
        (backup / 'sentinel').write_text('keep existing backup\n')
        candidate = home / 'candidate'
        candidate.write_text('''#!/bin/bash
printf '%s\\n' "$@" > "$HOME/probe-args"
[[ "$*" == *'--headless -u NONE -i NONE --noplugin -n'* ]] || exit 90
[[ "$*" == *'nvim-0.11.2'* && "$*" == *'type(jit)'* ]] || exit 91
exit ''' + ('0' if compatible else '1') + '\n')
        candidate.chmod(0o755)
        if existing:
            shutil.copy(candidate, bin_dir / 'nvim')
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / 'config'),
                   XDG_DATA_HOME=str(home / 'data'), TMPDIR=str(home),
                   PATH=str(bin_dir) + ':/usr/bin:/bin')
        script = '''set -euo pipefail
DOTFILES_ROOT="$1"
source "$DOTFILES_ROOT/scripts/lib/common.sh"
source "$DOTFILES_ROOT/scripts/components.sh"
brew() {
  echo "$*" >> "$HOME/brew-calls"
  [[ "$BREW_OK" == yes ]] || return 42
  cp "$HOME/candidate" "$HOME/bin/nvim"
}
source "$DOTFILES_ROOT/scripts/install/neovim.sh"
source "$DOTFILES_ROOT/scripts/lib/temp.sh"
source "$DOTFILES_ROOT/scripts/install/lazyvim.sh"
'''
        env['BREW_OK'] = 'yes' if brew_ok else 'no'
        result = subprocess.run(['/bin/bash', '-c', script, 'test', str(ROOT)],
                                env=env, text=True, capture_output=True)
        success = compatible and brew_ok
        assert (result.returncode == 0) == success, (name, result)
        assert (backup / 'sentinel').read_text() == 'keep existing backup\n'
        if success:
            assert (config / 'init.lua').exists()
            assert (home / 'config/nvim_backup.1/sentinel').read_text() == 'keep user config\n'
        else:
            assert (config / 'sentinel').read_text() == 'keep user config\n'
            assert not (home / 'config/nvim_backup.1').exists()
            assert not list((home / 'config').glob('nvim.install.*'))
            if existing or brew_ok:
                assert '>= 0.11.2 built with LuaJIT' in result.stderr
                assert 'brew upgrade neovim' in result.stderr
                assert 'config has not been replaced' in result.stderr
        assert (home / 'brew-calls').exists() != existing
        print('PASS:', name, '(disposable command fixture)')

    if REAL_NVIM:
        module = (ROOT / 'scripts/install/neovim.sh').read_text()
        probe = module.split("-c '", 1)[1].split("'", 1)[0]
        clean_home = base / 'real-probe'
        clean_home.mkdir()
        env = dict(os.environ, HOME=str(clean_home), XDG_CONFIG_HOME=str(clean_home / 'config'),
                   XDG_DATA_HOME=str(clean_home / 'data'), XDG_STATE_HOME=str(clean_home / 'state'),
                   XDG_CACHE_HOME=str(clean_home / 'cache'))
        for version, luajit, expected in [
            ('0.9.5', True, False), ('0.11.1', True, False),
            ('0.11.2', True, True), ('0.12.0', True, True),
            ('0.11.2', False, False), ('0.12.0', False, False),
        ]:
            available = tuple(map(int, version.split('.'))) >= (0, 11, 2)
            setup = 'lua vim.fn.has = function(feature) assert(feature == "nvim-0.11.2"); return ' + ('1' if available else '0') + ' end; jit = ' + ('{version="fixture"}' if luajit else 'nil')
            result = subprocess.run([REAL_NVIM, '--headless', '-u', 'NONE', '-i', 'NONE',
                                     '--noplugin', '-n', '-c', setup, '-c', probe, '-c', 'qa!'],
                                    env=env, text=True, capture_output=True)
            assert (result.returncode == 0) == expected, (version, luajit, result)
            print('PASS: real Neovim Lua execution, mocked feature version', version, 'LuaJIT', luajit)
        result = subprocess.run([REAL_NVIM, '--headless', '-u', 'NONE', '-i', 'NONE',
                                 '--noplugin', '-n', '-c', probe, '-c', 'qa!'],
                                env=env, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        print('PASS: installed Neovim compatibility probe in isolated home')
    else:
        print('SKIP: real Lua predicate checks require an installed compatible Neovim')
