#!/usr/bin/env python3
"""Decides if the `Screenshots` CI job runs, from the event and the paths that a PR changes (ADR 0003).

CI only. Usage: scripts/ci_changes.py --event EVENT [--base SHA --head SHA]
Prints `screenshots=run` or `screenshots=skip` for $GITHUB_OUTPUT, and the reason on stderr.
A push always runs the job. A PR skips it only when every changed path is on the skip list.
When git cannot give the changed paths, the script exits 1, and the `Screenshots` job runs.
"""

import argparse
import fnmatch
import subprocess
import sys

# Paths that the app, the UI tests, and the `Screenshots` job do not use.
SKIP = ["docs/*", "design/*", ".claude/*", "*.md", "scripts/*"]
# Scripts that the `Screenshots` job runs. A change to one of them runs the job.
JOB_SCRIPTS = {"scripts/ci-select-xcode.sh", "scripts/export-screenshots.py", "scripts/ci_changes.py"}


def is_skipped(path):
    """True when a change to this path cannot change the app, the UI tests, or the `Screenshots` job."""
    if path in JOB_SCRIPTS:
        return False
    # fnmatch's `*` also matches `/`, so `docs/*` covers every file below docs/, and `*.md` every Markdown file.
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in SKIP)


def decide(event, paths):
    """`run` or `skip`. A push always runs. An empty list runs, because it means the list is wrong."""
    if event != "pull_request":
        return "run"
    if not paths:
        return "run"
    return "skip" if all(is_skipped(p) for p in paths) else "run"


def changed_paths(base, head, cwd=None):
    """The paths that change between the merge base of `base` and `head`, and `head`.

    Raises RuntimeError when git fails, for example when a commit or the merge base is missing.
    """
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...{head}"], cwd=cwd, capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"git diff {base}...{head} failed: {result.stderr.strip()}")
    return [line for line in result.stdout.splitlines() if line]


def main(argv=None, cwd=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", required=True)
    parser.add_argument("--base")
    parser.add_argument("--head")
    args = parser.parse_args(argv)

    paths = []
    if args.event == "pull_request":
        if not args.base or not args.head:
            print("A pull_request needs --base and --head", file=sys.stderr)
            return 1
        try:
            paths = changed_paths(args.base, args.head, cwd=cwd)
        except RuntimeError as error:
            print(error, file=sys.stderr)
            return 1
        for path in paths:
            print(f"{'skip' if is_skipped(path) else 'run '} {path}", file=sys.stderr)

    decision = decide(args.event, paths)
    print(f"Screenshots: {decision} ({args.event}, {len(paths)} changed paths)", file=sys.stderr)
    print(f"screenshots={decision}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
