"""A static test of .github/workflows/release.yml (CRAFT-76, CRAFT-77, CRAFT-102). Run: python3 -m unittest discover -s scripts -p 'test_*.py'

It reads the workflow as text, split by its indentation, so it needs no YAML package.
"""

import os
import pathlib
import re
import subprocess
import tempfile
import unittest

WORKFLOW = pathlib.Path(__file__).resolve().parent.parent / ".github/workflows/release.yml"
SECRETS = {"ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"}


def blocks(text, indent):
    """The `key:` blocks at this indentation, as {key: text of the block}. Comments and blank lines are left out."""
    result, key = {}, None
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        width = len(line) - len(line.lstrip())
        if width < indent:
            key = None
        elif width == indent and re.match(r"[\w-]+:", line.strip()):
            key = line.strip().split(":", 1)[0]
            result[key] = ""
        if key is not None:
            result[key] += line + "\n"
    return result


def steps(job):
    """The steps of a job, in order, as text."""
    found, current = [], None
    for line in job.splitlines():
        if re.match(r"^      - ", line):
            current = [line]
            found.append(current)
        elif current is not None and (line.startswith("        ") or not line.strip()):
            current.append(line)
        else:
            current = None
    return ["\n".join(s) for s in found]


def index_of(items, needle):
    return next(i for i, s in enumerate(items) if needle in s)


class ReleaseWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = WORKFLOW.read_text()
        cls.top = blocks(cls.text, 0)
        cls.jobs = blocks(cls.top["jobs"], 2)
        cls.release = cls.jobs["release"]
        cls.tag = cls.jobs["tag"]

    def test_the_only_trigger_is_workflow_dispatch(self):
        self.assertEqual(list(blocks(self.top["on"], 2)), ["workflow_dispatch"])

    def test_workflow_dispatch_takes_no_inputs(self):
        self.assertEqual(blocks(self.top["on"], 2)["workflow_dispatch"], "  workflow_dispatch:\n")

    def test_the_jobs_are_release_and_tag(self):
        self.assertEqual(list(self.jobs), ["release", "tag"])

    def test_release_needs_no_job(self):
        self.assertNotIn("needs", blocks(self.release, 4))

    def test_tag_sets_an_identity_then_pushes_an_annotated_tag_with_one_message(self):
        run = tag_script(self.tag)
        name = run.index("git config user.name")
        email = run.index("git config user.email")
        annotated = run.index("git tag -a")
        self.assertLess(max(name, email), annotated)
        tag_line = next(line for line in run.splitlines() if "git tag -a" in line)
        self.assertEqual(tag_line.count(" -m "), 1, tag_line)
        self.assertIn('-m "Release $GITHUB_RUN_NUMBER"', tag_line)

    def test_release_runs_only_on_main_in_testflight(self):
        self.assertIn("    if: github.ref == 'refs/heads/main'\n", self.release)
        self.assertIn("    environment: testflight\n", self.release)

    def test_release_uses_the_runner_and_xcode_of_app_ios(self):
        self.assertIn("    runs-on: macos-26\n", self.release)
        self.assertIn("scripts/ci-select-xcode.sh", self.release)
        self.assertIn("xcodegen generate", self.release)

    def test_release_archives_checks_exports_checks_then_uploads(self):
        s = steps(self.release)
        order = [
            index_of(s, "scripts/release-archive.sh"),
            index_of(s, "release_check.py archive"),
            index_of(s, "-exportArchive"),
            index_of(s, "release_check.py entitlements"),
            index_of(s, "altool --upload-app"),
        ]
        self.assertEqual(order, sorted(order))
        self.assertEqual(sum("altool" in step for step in s), 1)

    def test_the_archive_check_reads_the_ad_hoc_signature(self):
        # Without it, an archive that lost its entitlements reaches the export (the first Release run).
        s = steps(self.release)
        self.assertIn("--signed", s[index_of(s, "release_check.py archive")])

    def test_the_build_number_is_the_run_number(self):
        archive = steps(self.release)[index_of(steps(self.release), "scripts/release-archive.sh")]
        self.assertIn('"$GITHUB_RUN_NUMBER"', archive)

    def test_tag_needs_release_has_no_environment_and_can_write(self):
        self.assertIn("    needs: release\n", self.tag)
        self.assertNotIn("environment", self.tag)
        self.assertIn("contents: write", blocks(self.tag, 4)["permissions"])
        self.assertIn("refs/tags/release/$GITHUB_RUN_NUMBER", self.tag)

    def test_release_cannot_write_the_repo(self):
        self.assertNotIn("write", blocks(self.release, 4)["permissions"])
        self.assertNotIn("write", self.top["permissions"])

    def test_runs_queue_and_never_cancel(self):
        concurrency = self.top["concurrency"]
        self.assertIn("  group: release\n", concurrency)
        self.assertIn("  cancel-in-progress: false\n", concurrency)

    def test_only_the_three_secrets_and_only_in_release(self):
        used = set(re.findall(r"secrets\.(\w+)", self.text))
        self.assertEqual(used, SECRETS)
        self.assertEqual(re.findall(r"secrets\.", self.release), re.findall(r"secrets\.", self.text))
        # A secret reaches a step only through its env, never written into a run script.
        for step in steps(self.release):
            run = step.split("run:", 1)[1] if "run:" in step else ""
            self.assertNotIn("secrets.", run, step)

    def test_the_key_goes_to_runner_temp_and_is_removed_always(self):
        s = steps(self.release)
        write = s[index_of(s, '"$ASC_KEY_P8"')]
        self.assertIn('"$RUNNER_TEMP/private_keys/', write)
        remove = s[-1]
        self.assertIn("if: always()", remove)
        self.assertIn('rm -rf "$RUNNER_TEMP/private_keys"', remove)

    def test_no_step_traces_its_commands(self):
        self.assertIsNone(re.search(r"set\s+(-\w*x|-o\s+xtrace)", self.text))
        self.assertNotIn("bash -x", self.text)


def tag_script(tag_job):
    """The run script of the step that pushes the tag, without its YAML indentation."""
    s = steps(tag_job)
    step = s[index_of(s, "git tag -a")]
    lines = step.split("run: |", 1)[1].splitlines()[1:]
    return "\n".join(line[10:] for line in lines) + "\n"


class TagScriptTests(unittest.TestCase):
    """Runs the tag step of release.yml word for word in a repository with no other git identity."""

    def test_the_tag_step_pushes_an_annotated_tag_with_the_bot_tagger_and_the_release_message(self):
        run = tag_script(blocks(blocks(WORKFLOW.read_text(), 0)["jobs"], 2)["tag"])
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            env = {
                "PATH": os.environ["PATH"],
                "HOME": str(home),
                "GIT_CONFIG_GLOBAL": os.devnull,
                "GIT_CONFIG_NOSYSTEM": "1",
                "GITHUB_RUN_NUMBER": "7",
            }

            def git(*args, cwd):
                return subprocess.run(
                    ["git", *args], cwd=cwd, env=env, check=True, capture_output=True, text=True
                ).stdout.strip()

            origin, clone = home / "origin.git", home / "clone"
            git("init", "-q", "--bare", "-b", "main", str(origin), cwd=tmp)
            git("init", "-q", "-b", "main", str(clone), cwd=tmp)
            # Only a commit made with an inline identity. Git may not guess one, so the step must set its own.
            git("config", "user.useConfigOnly", "true", cwd=clone)
            git("remote", "add", "origin", str(origin), cwd=clone)
            (clone / "README.md").write_text("x")
            git("add", "-A", cwd=clone)
            git("-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "-m", "x", cwd=clone)
            env["GITHUB_SHA"] = git("rev-parse", "HEAD", cwd=clone)

            subprocess.run(["bash", "-c", run], cwd=clone, env=env, check=True, capture_output=True, text=True)

            self.assertEqual(git("cat-file", "-t", "release/7", cwd=origin), "tag")
            tagger = git("for-each-ref", "--format=%(taggername) %(taggeremail)", "refs/tags/release/7", cwd=origin)
            self.assertEqual(tagger, "github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>")
            message = git("for-each-ref", "--format=%(contents)", "refs/tags/release/7", cwd=origin)
            self.assertEqual(message, "Release 7")
            self.assertEqual(git("rev-parse", "release/7^{commit}", cwd=origin), env["GITHUB_SHA"])


if __name__ == "__main__":
    unittest.main()
