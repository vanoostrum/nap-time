"""The CloudKit schema run is Debug only (CRAFT-77, CRAFT-81). Run: python3 -m unittest discover -s scripts -p 'test_*.py'"""

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


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
