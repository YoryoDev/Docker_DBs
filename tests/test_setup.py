"""Safe regression checks: temporary dummy configuration and mocked Docker only."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PROJECTS = {
    "mdb": "mariadb", "mongo": "mongodb", "sql22": "mssql2022",
    "sql25": "mssql2025", "mysql": "mysql", "ora": "oracle19c",
    "pg17": "postgresql17", "pg18": "postgresql18",
}


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ddbs-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo with spaces"
        self.root.mkdir()
        self.env = {key: os.environ[key] for key in ("PATH", "HOME")}
        self.env["DDBS_HOME"] = str(self.root)

    def run_command(self, args):
        return subprocess.run(args, cwd=self.root, env=self.env,
                              text=True, capture_output=True, timeout=30)

    def check_shell(self, shell, filename):
        if not shutil.which(shell):
            self.skipTest(f"{shell} unavailable")
        source = f'source "{ROOT / filename}"; '
        if shell == "bash":
            setup = 'shopt -s expand_aliases; docker() { printf "%s\\n" "$@"; }; '
            command = [shell, "--noprofile", "--norc", "-c"]
        else:
            setup = 'function docker; printf "%s\\n" $argv; end; '
            command = [shell, "--no-config", "-c"]
        for prefix, folder in PROJECTS.items():
            for action, args in (("up", ["up", "-d"]), ("down", ["down"])):
                with self.subTest(shell=shell, folder=folder, action=action):
                    result = self.run_command(command + [source + setup + f'eval "{prefix}-{action} --timeout 7"'])
                    self.assertEqual(result.returncode, 0, result.stderr)
                    path = self.root / folder
                    self.assertEqual(result.stdout.splitlines(), [
                        "compose", "-f", str(path / "compose.yaml"),
                        "--project-directory", str(path), "--env-file", str(path / ".env"),
                        "--profile", folder, *args, "--timeout", "7",
                    ])
        result = self.run_command(command + [source + setup + 'eval "pg18-psql -c \'SELECT 1\'"'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"', result.stdout)
        self.assertEqual(result.stdout.splitlines()[-2:], ["-c", "SELECT 1"])
        failure = ('docker() { return 23; }; ' if shell == "bash"
                   else 'function docker; return 23; end; ')
        result = self.run_command(command + [source + failure + '_ddbs_project mysql mysql config --quiet'])
        self.assertEqual(result.returncode, 23)

    def test_bash_helpers(self):
        self.check_shell("bash", ".bash_aliases")

    def test_fish_helpers(self):
        self.check_shell("fish", "docker_dbs.fish")

    def test_powershell_helpers(self):
        if not shutil.which("pwsh"):
            self.skipTest("pwsh unavailable; PowerShell execution not verified")
        for prefix, folder in PROJECTS.items():
            code = (f'. "{ROOT / "DockerDBs.ps1"}"; '
                    'function docker { ConvertTo-Json -InputObject @($args) -Compress }; '
                    f'{prefix}-up --timeout 7')
            result = self.run_command(["pwsh", "-NoProfile", "-Command", code])
            self.assertEqual(result.returncode, 0, result.stderr)
            path = self.root / folder
            self.assertEqual(json.loads(result.stdout), [
                "compose", "-f", str(path / "compose.yaml"),
                "--project-directory", str(path), "--env-file", str(path / ".env"),
                "--profile", folder, "up", "-d", "--timeout", "7",
            ])

    def compose_fixture(self):
        # Never read or copy real .env files, examples, or credentials.
        shutil.copyfile(ROOT / "compose.yaml", self.root / "compose.yaml")
        for folder in PROJECTS.values():
            target = self.root / folder
            target.mkdir()
            text = (ROOT / folder / "compose.yaml").read_text()
            (target / "compose.yaml").write_text(text)
            names = set(re.findall(r"(?<!\$)\$\{([A-Z_]+)", text))
            values = {name: f"dummy_{folder}" for name in names}
            values["BIND_ADDRESS"] = "127.0.0.1"
            (target / ".env").write_text("".join(f"{key}={value}\n" for key, value in values.items()))

    def test_compose_root_and_standalone(self):
        if not shutil.which("docker"):
            self.skipTest("docker unavailable")
        self.compose_fixture()
        dummy_files = {folder: (self.root / folder / ".env").read_text()
                       for folder in PROJECTS.values()}
        for profile in [*PROJECTS.values(), "*"]:
            result = self.run_command(["docker", "compose", "--profile", profile, "config", "--quiet"])
            self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_command(["docker", "compose", "--profile", "postgresql18", "config", "--services"])
        self.assertEqual(set(result.stdout.splitlines()), {"postgresql", "postgresql18_init"})
        result = self.run_command(["docker", "compose", "--profile", "*", "config", "--format", "json"])
        self.assertEqual(result.returncode, 0, result.stderr)
        services = json.loads(result.stdout)["services"]
        self.assertEqual(services["postgresql"]["environment"]["POSTGRES_USER"], "dummy_postgresql18")
        self.assertEqual(services["postgresql17"]["environment"]["POSTGRES_USER"], "dummy_postgresql17")
        self.assertNotIn("oracle19c_login", services)
        # Root requires every env file even with only one selected profile.
        for folder in PROJECTS.values():
            if folder != "postgresql18":
                (self.root / folder / ".env").unlink()
        result = self.run_command(["docker", "compose", "--profile", "postgresql18", "config", "--quiet"])
        self.assertNotEqual(result.returncode, 0)
        result = self.run_command([
            "docker", "compose", "-f", "postgresql18/compose.yaml",
            "--env-file", "postgresql18/.env", "--profile", "postgresql18", "config", "--quiet",
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        for folder in PROJECTS.values():
            path = self.root / folder
            (path / ".env").write_text(dummy_files[folder])
            result = self.run_command([
                "docker", "compose", "-f", str(path / "compose.yaml"),
                "--env-file", str(path / ".env"), "--profile", folder, "config", "--quiet",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_persisted_identity_unchanged(self):
        for folder in PROJECTS.values():
            relative = f"{folder}/compose.yaml"
            before = subprocess.run(["git", "show", f"HEAD:{relative}"], cwd=ROOT,
                                    text=True, capture_output=True, check=True).stdout
            after = (ROOT / relative).read_text()
            # Named volume declarations, persistent mounts and container names.
            pattern = r"^.*(?:name:|\w+_(?:data|backup|log|jobs):/).*$"
            self.assertEqual(re.findall(pattern, before, re.M), re.findall(pattern, after, re.M))
            # Engine initialization variables remain byte-identical, including DB names.
            self.assertEqual(before.rsplit("    environment:", 1)[1].split("    healthcheck:")[0],
                             after.rsplit("    environment:", 1)[1].split("    healthcheck:")[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
