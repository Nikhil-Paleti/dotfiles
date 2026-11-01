"""Exercise platform checks against mocked kernels and os-release fixtures."""
from pathlib import Path
import os
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / 'scripts/platform.sh').read_text()
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    binary = root / 'bin'
    binary.mkdir()
    release = root / 'os-release'
    fixture = root / 'platform.sh'
    # Redirect the system-file dependency; production has no test-only path knobs.
    fixture.write_text(source.replace('/etc/os-release', str(release)))
    for distro, kernel, expected in [
        ('ID=ubuntu', '6.8.0', 0),
        ('ID=custom\nID_LIKE="ubuntu debian"', '6.8.0', 0),
        ('ID=notubuntu\nID_LIKE=notdebian', '6.8.0', 1),
        ('ID=ubuntu', '4.4.0-Microsoft', 1),
        ('ID=ubuntu', '6.6.0-microsoft-standard-WSL2', 0),
    ]:
        release.write_text(distro + '\n')
        uname = binary / 'uname'
        uname.write_text('#!/bin/bash\ncase "$1" in -s) echo Linux;; -m) echo x86_64;; -r) echo ' + kernel + ';; esac\n')
        uname.chmod(0o755)
        env = dict(os.environ, PATH=str(binary) + ':/usr/bin:/bin', XDG_CONFIG_HOME=str(root / 'config'), XDG_DATA_HOME=str(root / 'data'))
        result = subprocess.run(['/bin/bash', '-eu', str(fixture)], env=env, capture_output=True, text=True)
        assert result.returncode == expected, (distro, kernel, result.stderr)
print('PASS: exact Linux family checks and WSL1/WSL2 detection with mocked platform data. No package operations.')
