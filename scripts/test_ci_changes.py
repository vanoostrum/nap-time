"""Tests for ci_changes.py. Run: python3 -m unittest discover -s scripts -p 'test_*.py'"""

import contextlib
import io
import pathlib
import subprocess
import tempfile
import unittest

from ci_changes import decide, main

PR = "pull_request"


class DecideTests(unittest.TestCase):
    def test_each_line_of_the_skip_list_skips(self):
        for path in [
            "docs/adr/0003-ci-screenshots.md",
            "docs/notes.txt",
            "design/pages/home/day.html",
            "design/gallery.css",
            ".claude/craft.md",
            ".claude/skills/verify/SKILL.md",
            "GLOSSARY.md",
            "App/README.md",
            "scripts/verify.sh",
            "scripts/drive_app.py",
            "scripts/test_ci_changes.py",
        ]:
            with self.subTest(path=path):
                self.assertEqual(decide(PR, [path]), "skip")

    def test_only_skip_list_paths_skip(self):
        self.assertEqual(decide(PR, ["GLOSSARY.md", "docs/adr/0008-x.md", "design/pages/a.html"]), "skip")

    def test_the_scripts_that_the_job_runs_run(self):
        for path in ["scripts/ci-select-xcode.sh", "scripts/export-screenshots.py", "scripts/ci_changes.py"]:
            with self.subTest(path=path):
                self.assertEqual(decide(PR, [path]), "run")

    def test_app_and_build_paths_run(self):
        for path in [
            ".github/workflows/ci.yml",
            "App/HomeView.swift",
            "UITests/ChildFlowTests.swift",
            "Packages/Core/Sources/Core/AppMode.swift",
            "project.yml",
            ".xcode-version",
            "Store/FamilyStore.swift",
            "Widget/Widget.swift",
            "a-new-folder/file.swift",
        ]:
            with self.subTest(path=path):
                self.assertEqual(decide(PR, [path]), "run")

    def test_one_app_path_among_skipped_paths_runs(self):
        self.assertEqual(decide(PR, ["GLOSSARY.md", "docs/a.md", "App/HomeView.swift", "design/b.html"]), "run")

    def test_an_empty_list_runs(self):
        self.assertEqual(decide(PR, []), "run")

    def test_a_push_always_runs(self):
        self.assertEqual(decide("push", ["GLOSSARY.md"]), "run")
        self.assertEqual(decide("push", []), "run")


class MainTests(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.TemporaryDirectory()
        self.addCleanup(self.repo.cleanup)
        self.git("init", "-q", "-b", "main")
        self.base = self.commit("README.md")

    def git(self, *args):
        return subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args],
            cwd=self.repo.name, check=True, capture_output=True, text=True,
        ).stdout.strip()

    def commit(self, path):
        file = pathlib.Path(self.repo.name) / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(path)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", path)
        return self.git("rev-parse", "HEAD")

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(list(argv), cwd=self.repo.name)
        return code, out.getvalue(), err.getvalue()

    def test_a_docs_only_pr_skips(self):
        head = self.commit("docs/a.md")
        code, out, _ = self.run_main("--event", PR, "--base", self.base, "--head", head)
        self.assertEqual((code, out), (0, "screenshots=skip\n"))

    def test_a_pr_with_an_app_file_runs(self):
        self.commit("docs/a.md")
        head = self.commit("App/HomeView.swift")
        code, out, _ = self.run_main("--event", PR, "--base", self.base, "--head", head)
        self.assertEqual((code, out), (0, "screenshots=run\n"))

    def test_a_git_error_fails_and_prints_no_decision(self):
        code, out, err = self.run_main("--event", PR, "--base", "0" * 40, "--head", self.base)
        self.assertEqual((code, out), (1, ""))
        self.assertIn("git diff", err)

    def test_a_push_runs_without_git(self):
        code, out, _ = self.run_main("--event", "push")
        self.assertEqual((code, out), (0, "screenshots=run\n"))


if __name__ == "__main__":
    unittest.main()
