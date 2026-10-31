import subprocess
import sys
import tempfile
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'bootstrap.py'

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / 'home'
        self.home.mkdir()

    def run_install(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), '--home', str(self.home), *args], capture_output=True, text=True)

    def test_dry_run(self):
        self.assertEqual(self.run_install().returncode, 0)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_fresh_install_and_repeat_refusal(self):
        self.assertEqual(self.run_install('--apply').returncode, 0)
        self.assertTrue((self.home / '.config/nvim/lazy-lock.json').is_file())
        self.assertEqual((self.home / '.tmux.conf').read_bytes(), (SCRIPT.parent / 'tmux.conf').read_bytes())
        before = (self.home / '.zshrc').read_bytes()
        self.assertNotEqual(self.run_install('--apply').returncode, 0)
        self.assertEqual((self.home / '.zshrc').read_bytes(), before)

    def test_collision_preflight(self):
        (self.home / '.zprofile').write_text('keep')
        self.assertNotEqual(self.run_install('--apply').returncode, 0)
        self.assertFalse((self.home / '.config').exists())
        self.assertFalse((self.home / '.tmux.conf').exists())

    def test_broken_symlink(self):
        (self.home / '.tmux.conf').symlink_to(self.home / 'absent')
        self.assertNotEqual(self.run_install('--apply').returncode, 0)
        self.assertFalse((self.home / '.config').exists())

    def test_parent_symlink(self):
        outside = Path(self.tmp.name) / 'outside'
        outside.mkdir()
        (self.home / '.config').symlink_to(outside)
        self.assertNotEqual(self.run_install('--apply').returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_selected_components(self):
        self.assertEqual(self.run_install('--apply', '--components', 'tmux').returncode, 0)
        self.assertEqual([p.name for p in self.home.iterdir()], ['.tmux.conf'])

if __name__ == '__main__':
    unittest.main()
