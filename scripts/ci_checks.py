#!/usr/bin/env python3
"""Waits for CI checks on a commit and reports the first failed step with its log lines.

Usage: scripts/ci_checks.py [--sha SHA | --pr N] [--timeout MIN] CHECK [CHECK ...]
Default: the head commit of the open PR of the current branch.
Exit 0 when every check succeeded, 1 when one failed or did not finish in time.
"""

import argparse
import json
import re
import subprocess
import sys
import time

REPO = "vanoostrum/nap-time"


def gh(path, raw=False):
    args = ["gh", "api", path]
    if raw:
        args[2:2] = ["-H", "Accept: application/vnd.github.raw"]
    result = subprocess.run(args, capture_output=True, text=not raw)
    if result.returncode != 0:
        raise RuntimeError(f"gh api {path} failed: {result.stderr if not raw else result.stderr.decode()}")
    return result.stdout if raw else json.loads(result.stdout)


def head_sha(pr):
    if pr:
        return gh(f"repos/{REPO}/pulls/{pr}")["head"]["sha"]
    branch = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True).stdout.strip()
    owner = REPO.split("/")[0]
    pulls = gh(f"repos/{REPO}/pulls?head={owner}:{branch}&state=open")
    if not pulls:
        sys.exit(f"No open PR for branch {branch}. Pass --sha or --pr.")
    return pulls[0]["head"]["sha"]


def latest_runs(sha):
    """The newest check run per name for the commit."""
    runs = gh(f"repos/{REPO}/commits/{sha}/check-runs?per_page=100")["check_runs"]
    latest = {}
    for run in sorted(runs, key=lambda r: r["started_at"] or ""):
        latest[run["name"]] = run
    return latest


def job_log_lines(job_id):
    try:
        return gh(f"repos/{REPO}/actions/jobs/{job_id}/logs", raw=True).decode(errors="replace").splitlines()
    except RuntimeError:
        return None


def report_failure(run):
    print(f"FAIL: {run['name']} — {run['conclusion']} — {run['html_url']}")
    job = gh(f"repos/{REPO}/actions/jobs/{run['id']}")
    failed = next((s for s in job.get("steps", []) if s["conclusion"] == "failure"), None)
    step = failed["name"] if failed else None
    print(f"First failed step: {step or 'unknown'}")
    lines = job_log_lines(run["id"])
    if lines is not None:
        lines = [re.sub(r"^\S+Z ", "", line) for line in lines]
        # The first "##[error]" line ends the failed step. Show the error lines before it, or its last lines.
        end = next((i for i, line in enumerate(lines) if line.startswith("##[error]")), len(lines) - 1)
        errors = [line for line in lines[: end + 1] if re.search(r"error:|\*\* .* FAILED \*\*|✘", line, re.IGNORECASE)]
        print("Log lines:")
        for line in (errors[-40:] + [lines[end]]) if errors else lines[max(0, end - 40) : end + 1]:
            print("  " + line)
    else:
        print("The job log is not reachable. Annotations:")
        for a in gh(f"repos/{REPO}/check-runs/{run['id']}/annotations"):
            print(f"  {a.get('path')}:{a.get('start_line')}: {a.get('message')}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sha")
    parser.add_argument("--pr", type=int)
    parser.add_argument("--timeout", type=int, default=45, help="minutes")
    parser.add_argument("checks", nargs="+")
    args = parser.parse_args()
    sha = args.sha or head_sha(args.pr)
    print(f"Commit {sha}, checks: {', '.join(args.checks)}")

    deadline = time.time() + args.timeout * 60
    while True:
        runs = latest_runs(sha)
        failed = [runs[c] for c in args.checks if c in runs and runs[c]["status"] == "completed"
                  and runs[c]["conclusion"] not in ("success", "skipped", "neutral")]
        if failed:
            report_failure(failed[0])
            return 1
        done = [c for c in args.checks if c in runs and runs[c]["status"] == "completed"]
        if len(done) == len(args.checks):
            print("PASS: " + ", ".join(f"{c} success" for c in args.checks))
            return 0
        if time.time() > deadline:
            missing = [c for c in args.checks if c not in done]
            print(f"FAIL: not finished after {args.timeout} minutes: {', '.join(missing)}")
            return 1
        time.sleep(30)


if __name__ == "__main__":
    sys.exit(main())
