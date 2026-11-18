#!/usr/bin/env python3
"""Exports the `<entry point>.png` attachments of a UI test result bundle into one folder.

CI only. Usage: export-screenshots.py <bundle.xcresult> <output dir>
When a test ran more than once (a retry), each PNG comes from its last attempt.
Also writes test-summary.json with the result, the tests that failed on every attempt (`failedTests`),
and the tests that passed only on a retry (`retriedTests`). Each retried test gets a GitHub warning annotation.
"""

import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

bundle, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

if not bundle.exists():
    print(f"No result bundle at {bundle}", file=sys.stderr)
    sys.exit(0)

with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(
        ["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle), "--output-path", tmp],
        check=True,
    )
    manifest = json.loads((pathlib.Path(tmp) / "manifest.json").read_text())
    # The attachment of the last attempt wins: the highest repetition, then the latest time.
    chosen = {}
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            # Xcode adds a suffix such as `_0_<UUID>` to the name that the test gave.
            match = re.match(r"^(?P<entry>[a-z0-9-]+?)(?:\.png)?(?:_\d+_[0-9A-Fa-f-]+)?\.png$", name)
            if not match:
                continue
            order = (attachment.get("repetitionNumber") or 0, attachment.get("timestamp") or 0)
            if match["entry"] not in chosen or order > chosen[match["entry"]][0]:
                chosen[match["entry"]] = (order, name, attachment["exportedFileName"])
    for entry, (order, name, exported) in sorted(chosen.items()):
        target = out / f"{entry}.png"
        shutil.copyfile(pathlib.Path(tmp) / exported, target)
        print(f"{name} (repetition {order[0]}) -> {target.name}")


def xcresult(*args):
    return json.loads(
        subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", *args, "--path", str(bundle), "--compact"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    )


def test_cases(nodes):
    """Every node of type "Test Case" in the tree of `xcresulttool get test-results tests`."""
    for node in nodes:
        if node.get("nodeType") == "Test Case":
            yield node
        else:
            yield from test_cases(node.get("children", []))


def attempt_results(case):
    """The result of each attempt of a test case: the "Repetition" children, or the case itself."""
    runs = [c["result"] for c in case.get("children", []) if c.get("nodeType") == "Repetition" and "result" in c]
    return runs or [case.get("result")]


data = xcresult("summary")
failed, retried = set(), set()
cases = list(test_cases(xcresult("tests").get("testNodes", [])))
if not cases:
    # No test tree, for example after a crash before the first test: use the failures of the summary.
    failed = {f.get("testName", "?") for f in data.get("testFailures", [])}
for case in cases:
    name = case.get("nodeIdentifier") or case.get("name", "?")
    results = attempt_results(case)
    if len(results) > 1:
        print(f"{name}: {case.get('result')}, attempts: {', '.join(map(str, results))}")
    if all(r == "Failed" for r in results):
        failed.add(name)
    elif "Failed" in results:
        retried.add(name)
        print(f"::warning title=Retried UI test::{name} failed, then passed on its retry ({', '.join(results)})")
(out / "test-summary.json").write_text(
    json.dumps({"result": data.get("result"), "failedTests": sorted(failed), "retriedTests": sorted(retried)}, indent=2)
    + "\n"
)
print(f"result: {data.get('result')}, failed tests: {sorted(failed)}, retried tests: {sorted(retried)}")
