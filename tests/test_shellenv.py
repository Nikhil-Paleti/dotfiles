import os, pathlib, subprocess, tempfile
module=pathlib.Path(__file__).resolve().parents[1]/'scripts/install/shellenv.sh'
base=pathlib.Path(tempfile.mkdtemp(prefix='dotfiles-shellenv-'))
checks=[]
def fixture(name, shell='bash', platform='Linux', dirname='brew prefix'):
    root=base/name; root.mkdir(); home=root/'home'; home.mkdir(); prefix=root/dirname; (prefix/'bin').mkdir(parents=True)
    brew=prefix/'bin/brew'
    brew.write_text('#!/bin/bash\nif [[ "$1" == shellenv ]]; then printf "export PATH=%q:\\"$PATH\\"\\n" "'+str(prefix/'bin').replace('"','\\"')+'"; else echo fixture-brew; fi\n')
    brew.chmod(0o755)
    env=dict(HOME=str(home),SHELL='/bin/'+shell,PATH=str(prefix/'bin')+':/usr/bin:/bin',TERM='dumb')
    env.pop('ZDOTDIR',None)
    return home,prefix,env,platform
def apply(f, success=True):
    home,prefix,env,platform=f
    p=subprocess.run(['/bin/bash','-euc','os="$1"; source "$2"','test',platform,str(module)],env=env,text=True,capture_output=True)
    assert (p.returncode==0)==success,(p.returncode,p.stdout,p.stderr)
    return p

def startup(f,path,interactive=False,zsh=False):
    home,prefix,env,_=f; env=dict(env,PATH='/usr/bin:/bin')
    if zsh:
        args=['/bin/zsh','-d','-lic' if interactive else '-lc','command -v brew']
    elif interactive:
        args=['/bin/bash','--noprofile','-ic','command -v brew']
    else:
        args=['/bin/bash','--noprofile','-c','. "$1"; command -v brew','test',str(path)]
    p=subprocess.run(args,env=env,text=True,capture_output=True)
    assert p.returncode==0 and str(prefix/'bin/brew') in p.stdout,(args,p.stdout,p.stderr)

for login in ['.profile','.bash_profile','.bash_login']:
    f=fixture('bash-'+login); h,_,_,_=f
    if login!='.profile': (h/login).write_text('# existing login customization\nexport KEEP_ME=yes\n')
    (h/'.bashrc').write_text('# custom rc\ncase $- in *i*) ;; *) return;; esac\n')
    before=(h/'.bashrc').read_bytes(); apply(f)
    assert (h/'.bashrc').read_bytes().startswith(before)
    startup(f,h/login);startup(f,h/'.bashrc',True)
    first={p.name:p.read_bytes() for p in h.iterdir()};apply(f)
    assert first=={p.name:p.read_bytes() for p in h.iterdir()}
    checks.append('bash '+login+' login/nonlogin, preserve and rerun')
f=fixture('bash-precedence');h,_,_,_=f
(h/'.bash_profile').write_text('# highest priority\n');(h/'.bash_login').write_text('# lower priority\n');apply(f)
assert (h/'.bash_login').read_text()=='# lower priority\n';checks.append('bash login-file precedence')
f=fixture('custom');h,p,_,_=f
line='eval "$(\"'+str(p/'bin/brew')+'\" shellenv)"\n'
for n in ['.profile','.bashrc']:(h/n).write_text(line)
apply(f);assert all((h/n).read_text()==line for n in ['.profile','.bashrc']);startup(f,h/'.profile');checks.append('existing custom shellenv retained without duplication')
f=fixture('quote',dirname="brew's prefix");apply(f);startup(f,f[0]/'.profile');startup(f,f[0]/'.bashrc',True);checks.append('spaces and apostrophes in executable path')
f=fixture('zsh',shell='zsh',platform='Darwin');apply(f);startup(f,None,zsh=True);startup(f,None,True,True);checks.append('zsh actual login and interactive startup')
f=fixture('zdotdir',shell='zsh',platform='Darwin');f[2]['ZDOTDIR']=str(f[0]/'custom dotdir');apply(f);startup(f,None,True,True);checks.append('absolute custom ZDOTDIR created and used')
f=fixture('zsh-quote',shell='zsh',platform='Darwin',dirname="brew's prefix");apply(f);startup(f,None,True,True);checks.append('zsh apostrophe/space quoting')
for name,shell,platform in [('fish','fish','Linux'),('mac-bash','bash','Darwin')]:
    f=fixture(name,shell,platform);apply(f,False);assert not list(f[0].iterdir());checks.append('unsupported '+name+' fails without writes')
f=fixture('unset-shell');f[2].pop('SHELL');apply(f,False);checks.append('unset SHELL fails clearly')
f=fixture('relative-zdot',shell='zsh',platform='Darwin');f[2]['ZDOTDIR']='relative';apply(f,False);assert not list(f[0].iterdir());checks.append('relative ZDOTDIR refused')
for kind in ['symlink','directory','unwritable']:
    f=fixture(kind);h,_,_,_=f; target=h/'.bashrc'
    if kind=='symlink':
        other=h/'elsewhere';other.write_text('keep\n');target.symlink_to(other)
    elif kind=='directory':target.mkdir()
    else:target.write_text('keep\n');target.chmod(0o444)
    apply(f,False);assert not (h/'.profile').exists()
    if kind=='unwritable':target.chmod(0o644)
    checks.append(kind+' target refused before other profile writes')
f=fixture('missing-brew');f[2]['PATH']='/usr/bin:/bin';apply(f,False);assert not list(f[0].iterdir());checks.append('missing brew fails without writes')
f=fixture('existing-preferred');h,p,e,_=f;apply(f);alt=base/'alternate';alt.mkdir();b=alt/'brew';b.write_text('#!/bin/sh\necho preferred\n');b.chmod(0o755)
e=dict(e,PATH=str(alt)+':/usr/bin:/bin');r=subprocess.run(['/bin/bash','-c','. "$HOME/.profile"; command -v brew'],env=e,text=True,capture_output=True);assert r.stdout.strip()==str(b);checks.append('existing PATH-selected brew preserved')
print('\n'.join('PASS '+x for x in checks));print('Total:',len(checks));print('Fixtures:',base)
