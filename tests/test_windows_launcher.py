"""Static packaging/launcher contract tests (not Windows runtime tests)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LauncherTests(unittest.TestCase):
    def test_bat(self):
        bat = (ROOT / 'Запустить.bat').read_bytes()
        self.assertIn(b'local\\windows\\launcher.ps1', bat)
        self.assertIn(b'exit /b %RESULT%', bat)
        self.assertNotIn(b'\\r\\n', bat)

    def test_bootstrap_and_resume(self):
        script = (ROOT / 'local/windows/launcher.ps1').read_text()
        for expected in ['Docker.DockerDesktop', '--no-distribution', '-Verb RunAs',
                         'RunOnce', '-AutoStart', 'AddMinutes(5)', 'Ensure-Docker']:
            self.assertIn(expected, script)
        self.assertNotIn('Restart-Computer', script)
        self.assertNotIn('--accept-package-agreements', script)
        self.assertIn("if ($choice -in '', '1')", script)

    def test_local_only(self):
        compose = (ROOT / 'local/windows/compose.yaml').read_text()
        self.assertIn('127.0.0.1:3000:3000', compose)
        self.assertNotIn('privileged:', compose)


if __name__ == '__main__':
    unittest.main()
