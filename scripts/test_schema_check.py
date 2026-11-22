"""Tests for schema_check.py (CRAFT-77). Run: python3 -m unittest discover -s scripts -p 'test_*.py'"""

import contextlib
import io
import pathlib
import re
import subprocess
import tempfile
import unittest

from schema_check import MARKER, main

MODEL = "Store/NapTime.xcdatamodeld/NapTime.xcdatamodel/contents"
ROOT = pathlib.Path(__file__).resolve().parent.parent


class SchemaCheckTests(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.TemporaryDirectory()
        self.addCleanup(self.repo.cleanup)
        self.git("init", "-q", "-b", "main")
        self.commit(MODEL, "<model v1/>")

    def git(self, *args):
        return subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args],
            cwd=self.repo.name, check=True, capture_output=True, text=True,
        ).stdout.strip()

    def commit(self, path, content, message=None):
        file = pathlib.Path(self.repo.name) / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message or path)

    def marked_tag(self, build):
        self.git("tag", "-a", f"release/{build}", "-m", f"Release {build}", "-m", MARKER)

    def check(self, ticked):
        out, err = io.StringIO(), io.StringIO()
        env = {"SCHEMA_DEPLOYED": "true" if ticked else "false"}
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(env=env, cwd=self.repo.name)
        return code, out.getvalue()

    def assert_fails(self, out, *needles):
        errors = [line for line in out.splitlines() if line.startswith("::error::")]
        self.assertEqual(len(errors), 1, out)
        for needle in needles:
            self.assertIn(needle, errors[0])
        self.assertIn('the "Release" section of CLAUDE.md', errors[0])
        self.assertIn("start a new run with schema_deployed ticked", errors[0])

    def assert_passes(self, out, *needles):
        notices = [line for line in out.splitlines() if line.startswith("::notice::")]
        self.assertEqual(len(notices), 1, out)
        self.assertNotIn("::error::", out)
        for needle in needles:
            self.assertIn(needle, notices[0])

    def test_no_marked_tag_and_not_ticked_fails(self):
        code, out = self.check(ticked=False)
        self.assertNotEqual(code, 0)
        self.assert_fails(out, "No release tag has the schema check")

    def test_no_marked_tag_and_ticked_passes(self):
        code, out = self.check(ticked=True)
        self.assertEqual(code, 0)
        self.assert_passes(out, "schema_deployed is ticked", "no release tag has the schema check")

    def test_the_same_model_as_at_the_newest_marked_tag_passes(self):
        self.marked_tag(3)
        self.commit("App/HomeView.swift", "view")
        for ticked in (False, True):
            with self.subTest(ticked=ticked):
                code, out = self.check(ticked)
                self.assertEqual(code, 0)
                self.assert_passes(out, "release/3")

    def test_a_model_change_since_the_tag_fails_when_not_ticked(self):
        self.marked_tag(3)
        self.commit(MODEL, "<model v2/>")
        code, out = self.check(ticked=False)
        self.assertNotEqual(code, 0)
        self.assert_fails(out, "release/3", "changed")

    def test_a_model_change_since_the_tag_passes_when_ticked(self):
        self.marked_tag(3)
        self.commit(MODEL, "<model v2/>")
        code, out = self.check(ticked=True)
        self.assertEqual(code, 0)
        self.assert_passes(out, "release/3", "schema_deployed is ticked")

    def test_a_new_file_anywhere_in_the_model_folder_counts(self):
        self.marked_tag(3)
        self.commit("Store/NapTime.xcdatamodeld/NapTime 2.xcdatamodel/contents", "<model v2/>")
        code, out = self.check(ticked=False)
        self.assertNotEqual(code, 0)
        self.assert_fails(out, "release/3")

    def test_a_change_only_outside_the_model_folder_passes(self):
        self.marked_tag(3)
        self.commit("Store/FamilyStore.swift", "store")
        self.commit("Store/NapTime.xcdatamodeld.md", "a note next to the folder")
        code, out = self.check(ticked=False)
        self.assertEqual(code, 0)
        self.assert_passes(out, "release/3")

    def test_the_highest_build_number_wins_not_the_text_order(self):
        self.marked_tag(9)
        self.commit(MODEL, "<model v2/>")
        self.marked_tag(10)
        code, out = self.check(ticked=False)
        self.assertEqual(code, 0)
        self.assert_passes(out, "release/10")

    def test_the_highest_build_number_wins_not_the_tag_date(self):
        self.commit(MODEL, "<model v2/>")
        self.marked_tag(10)
        self.git("tag", "-a", "release/9", "HEAD~1", "-m", "Release 9", "-m", MARKER)
        code, out = self.check(ticked=False)
        self.assertEqual(code, 0)
        self.assert_passes(out, "release/10")

    def test_a_newer_lightweight_tag_is_ignored(self):
        self.marked_tag(3)
        self.commit(MODEL, "<model v2/>")
        self.git("tag", "release/4")
        code, out = self.check(ticked=False)
        self.assertNotEqual(code, 0)
        self.assert_fails(out, "release/3")

    def test_a_newer_annotated_tag_without_the_marker_is_ignored(self):
        self.marked_tag(3)
        self.commit(MODEL, "<model v2/>")
        self.git("tag", "-a", "release/4", "-m", "Release 4")
        code, out = self.check(ticked=False)
        self.assertNotEqual(code, 0)
        self.assert_fails(out, "release/3")

    def test_a_lightweight_tag_on_a_commit_with_the_marker_line_is_ignored(self):
        self.commit("App/HomeView.swift", "view", message=f"A commit\n\n{MARKER}")
        self.git("tag", "release/4")
        code, out = self.check(ticked=False)
        self.assertNotEqual(code, 0)
        self.assert_fails(out, "No release tag has the schema check")

    def test_tags_outside_release_are_ignored(self):
        self.git("tag", "-a", "other/5", "-m", MARKER)
        self.git("tag", "-a", "release/beta", "-m", MARKER)
        code, out = self.check(ticked=False)
        self.assertNotEqual(code, 0)
        self.assert_fails(out, "No release tag has the schema check")

    def test_a_git_error_fails_when_not_ticked_and_names_it(self):
        empty = tempfile.TemporaryDirectory()
        self.addCleanup(empty.cleanup)
        self.repo = empty  # not a git repository
        code, out = self.check(ticked=False)
        self.assertNotEqual(code, 0)
        self.assert_fails(out, "git")
        self.assertIn("not a git repository", out)

    def test_a_git_error_passes_when_ticked(self):
        empty = tempfile.TemporaryDirectory()
        self.addCleanup(empty.cleanup)
        self.repo = empty
        code, out = self.check(ticked=True)
        self.assertEqual(code, 0)
        self.assert_passes(out, "schema_deployed is ticked")


class DebugOnlySchemaCallTests(unittest.TestCase):
    """Each CloudKit write of the schema run in App/ and Store/ sits inside #if DEBUG, so a Release build has none.

    The calls: the schema call, and the zone save, share save, and zone delete that put cloudkit.share in the
    development schema (CRAFT-81).
    """

    CALLS = ("initializeCloudKitSchema(", "modifyRecordZones(", "modifyRecords(", "CKShare(recordZoneID:")

    @staticmethod
    def calls_in(text, call):
        """(line number, inside #if DEBUG) for each line of text that holds call."""
        found = []
        stack = []  # True for a branch that holds only in DEBUG
        for number, line in enumerate(text.splitlines(), 1):
            text = line.strip()
            if re.match(r"#if\b", text):
                stack.append(text == "#if DEBUG")
            elif re.match(r"#(else|elseif)\b", text) and stack:
                stack[-1] = False
            elif re.match(r"#endif\b", text) and stack:
                stack.pop()
            elif call in text and not text.startswith("//"):
                found.append((number, any(stack)))
        return found

    def calls(self, call):
        """(file, line number, inside #if DEBUG) for each call in App/ and Store/."""
        files = sorted([*ROOT.glob("App/**/*.swift"), *ROOT.glob("Store/**/*.swift")])
        return [(f.relative_to(ROOT), n, debug) for f in files for n, debug in self.calls_in(f.read_text(), call)]

    def test_there_is_each_call_and_each_one_is_debug_only(self):
        for call in self.CALLS:
            found = self.calls(call)
            with self.subTest(call=call):
                self.assertTrue(found, f"no call of {call} in App/ or Store/")
            for file, number, debug in found:
                with self.subTest(call=call, file=str(file), line=number):
                    self.assertTrue(debug, f"{file}:{number} calls {call} outside #if DEBUG")

    def test_a_call_outside_debug_is_found(self):
        source = "#if DEBUG\n  a()\n#else\n  let share = CKShare(recordZoneID: id)\n#endif\n"
        self.assertEqual(self.calls_in(source, "CKShare(recordZoneID:"), [(4, False)])
        source = "#if DEBUG\n  try await database.modifyRecordZones(saving: [zone], deleting: [])\n#endif\n"
        self.assertEqual(self.calls_in(source, "modifyRecordZones("), [(2, True)])


if __name__ == "__main__":
    unittest.main()
