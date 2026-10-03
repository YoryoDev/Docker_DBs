"""Safe regression checks: dummy configuration and mocked container CLIs only."""

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
    "sql25": "mssql2025", "mysql": "mysql",
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
        command = ([shell, "--noprofile", "--norc", "-c"] if shell == "bash"
                   else [shell, "--no-config", "-c"])
        for runtime, alias_prefix, helper in (
                ("docker", "", "_ddbs_project"),
                ("podman", "pod-", "_pddbs_project")):
            setup = (f'shopt -s expand_aliases; {runtime}() {{ printf "%s\\n" "$@"; }}; '
                     if shell == "bash"
                     else f'function {runtime}; printf "%s\\n" $argv; end; ')
            for prefix, folder in PROJECTS.items():
                for action, args in (("up", ["up", "-d"]), ("down", ["down"])):
                    with self.subTest(shell=shell, runtime=runtime, folder=folder, action=action):
                        invocation = f'eval "{alias_prefix}{prefix}-{action} --timeout 7"'
                        result = self.run_command(command + [source + setup + invocation])
                        self.assertEqual(result.returncode, 0, result.stderr)
                        path = self.root / folder
                        expected = ["compose", "-f", str(path / "compose.yaml")]
                        if runtime == "docker":
                            expected.extend(["--project-directory", str(path)])
                        expected.extend([
                            "--env-file", str(path / ".env"), "--profile", folder,
                            *args, "--timeout", "7",
                        ])
                        self.assertEqual(result.stdout.splitlines(), expected)
            invocation = f'eval "{alias_prefix}pg18-psql -c \'SELECT 1\'"'
            result = self.run_command(command + [source + setup + invocation])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(
                'PGPASSWORD="$POSTGRES_PASSWORD" PSQL_PAGER=cat exec psql -h localhost '
                '-U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"',
                result.stdout,
            )
            self.assertEqual(result.stdout.splitlines()[-2:], ["-c", "SELECT 1"])
            invocation = f'eval "{alias_prefix}sql25-client -Q \'SELECT 1\'"'
            result = self.run_command(command + [source + setup + invocation])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('SQLCMDPASSWORD="$MSSQL_SA_PASSWORD"', result.stdout)
            self.assertEqual(result.stdout.splitlines()[-2:], ["-Q", "SELECT 1"])
            for client, password_name in (
                    ("mdb-client", "MARIADB_ROOT_PASSWORD"),
                    ("mysql-client", "MYSQL_ROOT_PASSWORD")):
                invocation = f'eval "{alias_prefix}{client} -Nse \'SELECT 1\'"'
                result = self.run_command(command + [source + setup + invocation])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'MYSQL_PWD="${password_name}"', result.stdout)
                self.assertEqual(result.stdout.splitlines()[-2:], ["-Nse", "SELECT 1"])
            failure = (f'{runtime}() {{ return 23; }}; ' if shell == "bash"
                       else f'function {runtime}; return 23; end; ')
            result = self.run_command(command + [
                source + failure + f'{helper} mysql mysql config --quiet'])
            self.assertEqual(result.returncode, 23)

    def test_bash_helpers(self):
        self.check_shell("bash", ".bash_aliases")

    def test_fish_helpers(self):
        self.check_shell("fish", "docker_dbs.fish")

    def test_powershell_helpers(self):
        if not shutil.which("pwsh"):
            self.skipTest("pwsh unavailable; PowerShell execution not verified")
        for runtime, alias_prefix in (("docker", ""), ("podman", "pod-")):
            for prefix, folder in PROJECTS.items():
                code = (f'. "{ROOT / "DockerDBs.ps1"}"; '
                        f'function {runtime} {{ ConvertTo-Json -InputObject @($args) -Compress }}; '
                        f'{alias_prefix}{prefix}-up --timeout 7')
                result = self.run_command(["pwsh", "-NoProfile", "-Command", code])
                self.assertEqual(result.returncode, 0, result.stderr)
                path = self.root / folder
                expected = ["compose", "-f", str(path / "compose.yaml")]
                if runtime == "docker":
                    expected.extend(["--project-directory", str(path)])
                expected.extend([
                    "--env-file", str(path / ".env"), "--profile", folder,
                    "up", "-d", "--timeout", "7",
                ])
                self.assertEqual(json.loads(result.stdout), expected)

    def test_podman_alias_inventory(self):
        expected = {"pod-ddbs-ps", "pod-ddbs-images", "pod-ddbs-help"}
        extras = {
            "mdb": "client", "mongo": "cli", "sql22": "client",
            "sql25": "client", "mysql": "client", "pg17": "psql", "pg18": "psql",
        }
        for prefix in PROJECTS:
            expected.update(
                f"pod-{prefix}-{action}"
                for action in ("up", "down", "stop", "start", "restart", "logs", "shell", "status")
            )
            expected.add(f"pod-{prefix}-{extras[prefix]}")

        patterns = {
            ".bash_aliases": r"^alias (pod-[\w-]+)=",
            "docker_dbs.fish": r"^(?:alias|function) (pod-[\w-]+)",
            "DockerDBs.ps1": r"^(?:Set-Alias|function) (pod-[\w-]+)",
        }
        for filename, pattern in patterns.items():
            names = set(re.findall(pattern, (ROOT / filename).read_text(), re.M))
            self.assertEqual(names, expected, filename)

    def compose_fixture(self):
        # Never read or copy real .env files, examples, or credentials.
        shutil.copyfile(ROOT / "compose.yaml", self.root / "compose.yaml")
        for folder in PROJECTS.values():
            target = self.root / folder
            target.mkdir()
            text = (ROOT / folder / "compose.yaml").read_text()
            (target / "compose.yaml").write_text(text)
            shutil.copytree(ROOT / folder / "config", target / "config")
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
        expected_services = {"postgresql" if folder == "postgresql18" else folder
                             for folder in PROJECTS.values()}
        expected_services.update(f"{folder}_init" for folder in PROJECTS.values())
        self.assertEqual(set(services), expected_services)
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

    def test_podman_compose_standalone(self):
        if not shutil.which("podman"):
            self.skipTest("podman unavailable")
        self.compose_fixture()
        for folder in PROJECTS.values():
            path = self.root / folder
            result = self.run_command([
                "podman", "compose", "-f", str(path / "compose.yaml"),
                "--env-file", str(path / ".env"), "--profile", folder, "config",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            result = self.run_command([
                "podman", "compose", "--dry-run", "-f", str(path / "compose.yaml"),
                "--env-file", str(path / ".env"), "--profile", folder, "up", "-d",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_podman_compose_root(self):
        if not shutil.which("podman"):
            self.skipTest("podman unavailable")
        version = self.run_command(["podman", "compose", "version"])
        output = version.stdout + version.stderr
        if "podman-compose" in output:
            self.skipTest("podman-compose does not support include entries with per-project env_file")
        self.compose_fixture()
        result = self.run_command([
            "podman", "compose", "--profile", "*", "config", "--quiet",
        ])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_selinux_relabel_on_config_bind_mounts(self):
        for folder in PROJECTS.values():
            text = (ROOT / folder / "compose.yaml").read_text()
            mounts = [line.strip() for line in text.splitlines() if "./config/" in line]
            self.assertTrue(mounts, folder)
            self.assertTrue(all(line.endswith(":ro,Z") for line in mounts), mounts)

    def test_podman_compose_avoids_infra_less_pods(self):
        for folder in PROJECTS.values():
            text = (ROOT / folder / "compose.yaml").read_text()
            self.assertRegex(text, r"(?m)^x-podman:\n  in_pod: false$", folder)

    def test_docker_hub_images_are_fully_qualified(self):
        for folder in PROJECTS.values():
            text = (ROOT / folder / "compose.yaml").read_text()
            for image in re.findall(r"^\s+image:\s+(\S+)$", text, re.M):
                if not image.startswith("mcr.microsoft.com/"):
                    self.assertTrue(image.startswith("docker.io/library/"), (folder, image))

    def test_sql_server_has_shutdown_grace_period(self):
        for folder in ("mssql2022", "mssql2025"):
            text = (ROOT / folder / "compose.yaml").read_text()
            self.assertIn("    stop_grace_period: 60s\n", text, folder)

    def test_sql_server_forwards_shutdown_signals(self):
        for folder in ("mssql2022", "mssql2025"):
            text = (ROOT / folder / "compose.yaml").read_text()
            self.assertIn(
                '    entrypoint: ["/bin/bash", "/usr/local/bin/launch_sqlservr.sh"]',
                text,
                folder,
            )
            self.assertIn('    command: ["/opt/mssql/bin/sqlservr"]', text, folder)
            self.assertIn(
                "./config/launch_sqlservr.sh:/usr/local/bin/launch_sqlservr.sh:ro,Z",
                text,
                folder,
            )
            wrapper = (ROOT / folder / "config" / "launch_sqlservr.sh").read_text()
            self.assertIn("trap 'forward_signal TERM' TERM", wrapper, folder)
            self.assertIn('kill "-$signal" "$sqlservr_pid"', wrapper, folder)

    def test_sql_server_helpers_use_shutdown_grace_period(self):
        expectations = {
            ".bash_aliases": (
                "docker stop --time 60 sqlserver25",
                "docker restart --time 60 sqlserver25",
                "_pddbs_podman stop --time 60 sqlserver25",
                "_pddbs_podman restart --time 60 sqlserver25",
            ),
            "docker_dbs.fish": (
                "docker stop --time 60 sqlserver25",
                "docker restart --time 60 sqlserver25",
                "_pddbs_podman stop --time 60 sqlserver25",
                "_pddbs_podman restart --time 60 sqlserver25",
            ),
            "DockerDBs.ps1": (
                "docker stop --time 60 sqlserver25",
                "docker restart --time 60 sqlserver25",
                "Invoke-DDBSPodman stop --time 60 sqlserver25",
                "Invoke-DDBSPodman restart --time 60 sqlserver25",
            ),
        }
        for filename, commands in expectations.items():
            text = (ROOT / filename).read_text()
            for command in commands:
                self.assertIn(command, text, filename)

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
