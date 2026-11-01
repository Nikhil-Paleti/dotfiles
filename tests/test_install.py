import os,subprocess,tempfile,pathlib,sys
script=str(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else str(pathlib.Path(__file__).resolve().parents[1] / 'install.sh')).resolve())
with tempfile.TemporaryDirectory() as tmp:
 r=pathlib.Path(tmp); b=r/'bin'; b.mkdir(); home=r/'home'; home.mkdir(); prefix=r/'brew'; log=r/'log'
 def tool(name,body='exit 0'):
  p=b/name;p.write_text('#!/bin/bash\n'+body+'\n');p.chmod(0o755)
 tool('uname','case "$1" in -s) echo Darwin;; -m) echo arm64;; esac')
 tool('xcode-select')
 tool('brew',f'''case "$1" in
 --prefix) [[ ! -f '{r}/fail-prefix' ]] || exit 94; echo '{prefix}';;
 update) echo update >> '{log}';;
 list)
  [[ ! -f '{r}/fail-list' ]] || exit 95
  [[ $# -ne 2 ]] || exit 0
  case "$4" in tmux|node) exit 0;; *) exit 1;; esac;;
 upgrade)
  [[ "$NONINTERACTIVE" == 1 ]] || exit 70
  [[ ! -f '{r}/fail-upgrade' ]] || exit 98
  echo "$*" >> '{log}';;
 install)
  [[ ! -f '{r}/fail-brew' ]] || exit 97
  [[ "$NONINTERACTIVE" == 1 ]] || exit 70
  if read -r input; then exit 71; fi
  echo "$*" >> '{log}'
  case "$2" in
   tmux) printf '#!/bin/bash\\nexit 0\\n' > '{b}/tmux'; chmod +x '{b}/tmux';;
   *) exit 44;; esac;;
 *) exit 45;; esac''')
 for x in ['curl','rg','fd','lazygit','fzf','tree-sitter','node','npm','zsh','stylua','shfmt','shellcheck','cc','make']:
  tool(x, f'echo UNEXPECTED-{x} >> "{log}"; exit 80')
 # Real Python is used only for atomic rename into the isolated temporary home.
 (b/'python3').symlink_to(sys.executable)
 tool('git',f'''if [[ "$1" == --version ]]; then echo 'git version 2.50.0'; else
  for target; do :; done
  mkdir -p "$target/.git"; echo starter > "$target/init.lua"
  echo CLONE >> '{log}'
 fi''')
 tool('nvim',f'''if [[ "$1" == --version ]]; then echo 'NVIM v0.11.5'; else
  [[ "$NVIM_APPNAME" == nvim ]] || exit 84
  [[ "$*" == *"-u $XDG_CONFIG_HOME/nvim/init.lua"* ]] || exit 87
  [[ -z "${{VIMINIT+x}}" && -z "${{EXINIT+x}}" ]] || exit 88
  [[ "$XDG_CONFIG_HOME" != '{home}/.config' ]] || exit 85
  echo SYNC >> '{log}'
  [[ ! -f '{r}/fail-sync' ]] || exit 86
  if [[ -f '{r}/race' ]]; then mkdir -p '{home}/.config/nvim'; echo untouched > '{home}/.config/nvim/init.lua'; fi
 fi''')
 for f in ['zsh-autosuggestions','zsh-completions','zsh-syntax-highlighting']:(prefix/'share'/f).mkdir(parents=True)
 (home/'.config/nvim').mkdir(parents=True); keep=home/'.config/nvim/init.lua';keep.write_text('preserve')
 profiles=['.zprofile','.zshrc','.bashrc','.bash_profile','.profile']
 for name in profiles:(home/name).write_text('UNCHANGED-'+name)
 victim=r/'must-survive';victim.mkdir();(victim/'keep').write_text('untouched')
 (victim/'.dotfiles-installer-owner').write_text('inherited-owner')
 env=dict(os.environ,PATH=str(b)+':/usr/bin:/bin',HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'))
 env.update(VIMINIT='must-not-run',EXINIT='must-not-run',stage=str(victim),scratch=str(victim),_dotfiles_stage_dir=str(victim),_dotfiles_download_dir=str(victim),_dotfiles_cleanup_owner='inherited-owner')
 def run(*args):return subprocess.run(['/bin/bash',script,*args],env=env,text=True,capture_output=True,timeout=15,input='DO-NOT-READ\n',cwd=r)
 p=run('--check');assert p.returncode==1,p.stderr;assert not log.exists();assert 'codex' not in p.stdout.lower()
 # Failure after cleanup trap installation must not consume inherited paths.
 (r/'fail-brew').touch();p=run('--install');assert p.returncode==97,(p.stdout,p.stderr)
 assert (victim/'keep').read_text()=='untouched'
 (r/'fail-brew').unlink()
 p=run('--install');assert p.returncode==0,(p.stdout,p.stderr);assert log.read_text()=='install tmux\n';assert keep.read_text()=='preserve'
 assert (victim/'keep').read_text()=='untouched' 
 p=run('--install');assert p.returncode==0;assert log.read_text()=='install tmux\n'
 p=run('--check');assert p.returncode==0
 # A Mason-only tool must be discovered before check.sh reports availability.
 mason=home/'.local/share/nvim/mason/bin';mason.mkdir(parents=True)
 (b/'stylua').rename(mason/'stylua')
 p=run('--check');assert p.returncode==0,(p.stdout,p.stderr)
 assert 'stylua                   present' in p.stdout
 for name in profiles:assert (home/name).read_text()=='UNCHANGED-'+name
 # Interrupted sync must not publish an incomplete config; rerun must retry.
 keep.unlink();(home/'.config/nvim').rmdir();(r/'fail-sync').touch()
 p=run('--install');assert p.returncode!=0;assert not keep.parent.exists();assert not list((home/'.config').glob('nvim.install.*'))
 (r/'fail-sync').unlink();p=run('--install');assert p.returncode==0,(p.stdout,p.stderr);assert keep.read_text()=='starter\n'
 before=log.read_text();p=run('--install');assert p.returncode==0;assert log.read_text()==before
 # Concurrent collision during staging must survive atomic publication refusal.
 keep.unlink();import shutil;shutil.rmtree(keep.parent);(r/'race').touch()
 p=run('--install');assert p.returncode!=0;assert keep.read_text()=='untouched\n';assert not (keep.parent/'nvim').exists()
 (r/'race').unlink()
 # No custom version checks: an existing older tool is retained.
 tool('nvim',"echo 'NVIM v0.10.0'");before=log.read_text();p=run('--install');assert p.returncode==0;assert log.read_text()==before
 p=run('--update');assert p.returncode==0,(p.stdout,p.stderr)
 assert log.read_text()[len(before):]=='update\nupgrade --formula tmux\nupgrade --formula node\n'
 assert keep.read_text()=='untouched\n'
 # Missing or externally managed formulas were not installed; npm/node deduped.
 (r/'fail-upgrade').touch();p=run('--update');assert p.returncode==98,(p.stdout,p.stderr)
 (r/'fail-upgrade').unlink()
 before=log.read_text()
 p=subprocess.run(['/bin/bash','-c','have() { return 1; }; source "$1"','test',str(pathlib.Path(script).parent/'scripts/update.sh')],env=env,capture_output=True,text=True)
 assert p.returncode==1;assert 'Homebrew not found' in p.stderr;assert log.read_text()==before
 # Failures of Homebrew discovery/inventory must not look like missing tools.
 for failure, expected in [('fail-prefix',94),('fail-list',95)]:
  (r/failure).touch();p=run('--update');assert p.returncode==expected,(p.stdout,p.stderr);(r/failure).unlink()
 # Relative repo entry point must work even when CDPATH causes cd to print.
 before=log.read_text()
 env['CDPATH']=str(pathlib.Path(script).parent.parent)
 p=subprocess.run(['/bin/bash',pathlib.Path(script).parent.name+'/install.sh','--check'],cwd=pathlib.Path(script).parent.parent,env=env,capture_output=True,text=True)
 assert p.returncode==0,(p.stdout,p.stderr);assert log.read_text()==before
 env.pop('CDPATH')
 # Reject relative XDG paths before any write/package-manager call.
 env['XDG_CONFIG_HOME']='relative';p=run('--install');assert p.returncode==1;assert 'absolute' in p.stderr
 env['XDG_CONFIG_HOME']=str(home/'.config')
 p=run('--help','extra');assert p.returncode==2
 p=run('--bogus');assert p.returncode==2
 for name in profiles:assert (home/name).read_text()=='UNCHANGED-'+name
 assert (victim/'keep').read_text()=='untouched'
 print('PASS: Homebrew errors propagated; CDPATH and XDG paths checked;  Codex excluded; check read-only; mock package installs noninteractive; profile bytes preserved; rerun idempotent; interrupted sync retries; real atomic publish refuses concurrent collision; existing versions retained; scoped/deduplicated updates and failures checked; bad arguments refused; hostile inherited cleanup paths survive early failure and normal exits.')
