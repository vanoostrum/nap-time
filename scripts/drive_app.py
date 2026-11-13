#!/usr/bin/env python3
"""Collects the screenshot evidence of a commit from the `Screenshots` CI job.

Usage: scripts/drive_app.py [--sha SHA | --pr N] [--out DIR] [--timeout MIN] [--entry-points a,b]
Default: the head commit of the open PR of the current branch, the entry points listed in
.claude/skills/drive-app/SKILL.md, and evidence in build/evidence/<sha>/.

It waits up to --timeout minutes (default 30) for the `Screenshots` run of the commit to exist and finish.
It downloads the `screenshots` artifact, or reads the branch `screenshots/<branch>` when the artifact host
is not reachable. It prints PASS, or FAIL with every reason, and exits 0 or 1.
"""

import argparse
import io
import json
import pathlib
import re
import subprocess
import sys
import time
import zipfile

REPO = "vanoostrum/nap-time"
CHECK = "Screenshots"
ROOT = pathlib.Path(__file__).resolve().parent.parent
SKILL = ROOT / ".claude/skills/drive-app/SKILL.md"


def gh(path, raw=False):
    args = ["gh", "api", path]
    if raw:
        args[2:2] = ["-H", "Accept: application/vnd.github.raw"]
    result = subprocess.run(args, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"gh api {path}: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout if raw else json.loads(result.stdout)


def expected_entry_points():
    """The names in the `## Entry points` list of the drive-app skill: lines like "- `home`: ...". """
    text = SKILL.read_text()
    section = text.split("## Entry points", 1)[1].split("\n## ", 1)[0]
    return re.findall(r"^- `([a-z0-9-]+)`", section, re.MULTILINE)


def find_commit(args):
    if args.sha:
        branches = gh(f"repos/{REPO}/commits/{args.sha}/pulls")
        return args.sha, (branches[0]["head"]["ref"] if branches else "main")
    if args.pr:
        pr = gh(f"repos/{REPO}/pulls/{args.pr}")
    else:
        branch = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True).stdout.strip()
        pulls = gh(f"repos/{REPO}/pulls?head={REPO.split('/')[0]}:{branch}&state=open")
        if not pulls:
            sys.exit(f"FAIL: no open PR for branch {branch}. Pass --sha or --pr.")
        pr = pulls[0]
    return pr["head"]["sha"], pr["head"]["ref"]


def wait_for_run(sha, minutes):
    deadline = time.time() + minutes * 60
    while True:
        runs = [r for r in gh(f"repos/{REPO}/commits/{sha}/check-runs?check_name={CHECK}")["check_runs"]]
        latest = max(runs, key=lambda r: r["started_at"] or "", default=None)
        if latest and latest["status"] == "completed":
            return latest
        if time.time() > deadline:
            state = latest["status"] if latest else "no run"
            return {"missing": f"no {CHECK} run finished for commit {sha} after {minutes} minutes ({state})"}
        time.sleep(30)


def from_artifact(run):
    """The PNG files of the `screenshots` artifact of the run, or None when the artifact host is not reachable."""
    job = gh(f"repos/{REPO}/actions/jobs/{run['id']}")
    artifacts = gh(f"repos/{REPO}/actions/runs/{job['run_id']}/artifacts")["artifacts"]
    artifact = next((a for a in artifacts if a["name"] == "screenshots"), None)
    if artifact is None:
        return {}, "artifact"
    try:
        data = gh(f"repos/{REPO}/actions/artifacts/{artifact['id']}/zip", raw=True)
        archive = zipfile.ZipFile(io.BytesIO(data))
    except (RuntimeError, zipfile.BadZipFile) as error:
        print(f"note: artifact not reachable ({str(error)[:120]}); reading the screenshots branch")
        return None, None
    return {pathlib.Path(n).name: archive.read(n) for n in archive.namelist()}, "artifact"


def from_branch(sha, branch):
    ref = f"screenshots/{branch}"
    try:
        listing = gh(f"repos/{REPO}/contents/{sha}?ref={ref}")
    except RuntimeError:
        return {}, f"branch {ref}"
    files = {item["name"]: gh(f"repos/{REPO}/contents/{sha}/{item['name']}?ref={ref}", raw=True) for item in listing}
    return files, f"branch {ref}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sha")
    parser.add_argument("--pr", type=int)
    parser.add_argument("--out")
    parser.add_argument("--timeout", type=int, default=30, help="minutes")
    parser.add_argument("--entry-points", help="comma-separated; default: the list in the drive-app skill")
    args = parser.parse_args()

    entry_points = args.entry_points.split(",") if args.entry_points else expected_entry_points()
    sha, branch = find_commit(args)
    out = pathlib.Path(args.out or ROOT / "build/evidence" / sha)
    print(f"Commit {sha} on {branch}. Entry points: {', '.join(entry_points)}")

    run = wait_for_run(sha, args.timeout)
    if "missing" in run:
        print(f"FAIL: {run['missing']}")
        return 1
    print(f"{CHECK} run: {run['conclusion']} — {run['html_url']}")

    files, source = from_artifact(run)
    if files is None:
        files, source = from_branch(sha, branch)
    print(f"Source: {source}")

    out.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        (out / name).write_bytes(data)

    failures = []
    if run["conclusion"] != "success":
        summary = json.loads(files["test-summary.json"]) if "test-summary.json" in files else {}
        failed = summary.get("failedTests") or ["unknown: no test-summary.json"]
        failures.append(f"{CHECK} run {run['conclusion']}; failed tests: {', '.join(failed)}")
    for entry in entry_points:
        png = files.get(f"{entry}.png")
        if png is None:
            failures.append(f"missing entry point: {entry} (no {entry}.png)")
        elif not png.startswith(b"\x89PNG"):
            failures.append(f"entry point {entry}: {entry}.png is not a PNG")
        else:
            print(f"evidence: {out / (entry + '.png')} ({len(png)} bytes)")

    for failure in failures:
        print(f"FAIL: {failure}")
    if not failures:
        print(f"PASS: {len(entry_points)} entry points from {source}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
