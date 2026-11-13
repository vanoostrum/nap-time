#!/usr/bin/env python3
"""Exports the `<entry point>.png` attachments of a UI test result bundle into one folder.

CI only. Usage: export-screenshots.py <bundle.xcresult> <output dir>
Also writes test-summary.json with the result and the names of the failed tests.
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
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            # Xcode adds a suffix such as `_0_<UUID>` to the name that the test gave.
            match = re.match(r"^(?P<entry>[a-z0-9-]+?)(?:\.png)?(?:_\d+_[0-9A-Fa-f-]+)?\.png$", name)
            if not match:
                continue
            target = out / f"{match['entry']}.png"
            shutil.copyfile(pathlib.Path(tmp) / attachment["exportedFileName"], target)
            print(f"{name} -> {target.name}")

summary = subprocess.run(
    ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle), "--compact"],
    check=True,
    capture_output=True,
    text=True,
).stdout
data = json.loads(summary)
failed = sorted({f.get("testName", "?") for f in data.get("testFailures", [])})
(out / "test-summary.json").write_text(
    json.dumps({"result": data.get("result"), "failedTests": failed}, indent=2) + "\n"
)
print(f"result: {data.get('result')}, failed tests: {failed}")
