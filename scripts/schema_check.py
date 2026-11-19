#!/usr/bin/env python3
"""The schema check of the workflow `Release` (ADR 0011, CRAFT-77).

Fails when the Core Data model changed since the newest release tag from a run that had this check, or when no such
tag exists, and the input `schema_deployed` is not ticked. A run that had the check marks its tag: an annotated tag
`release/<build number>` whose message holds the line `schema-check: yes`. "Newest" is the highest build number.

Usage, in the job `schema` of release.yml: SCHEMA_DEPLOYED=true|false python3 scripts/schema_check.py
"""

import os
import re
import subprocess
import sys

MARKER = "schema-check: yes"
MODEL = "Store/NapTime.xcdatamodeld"
TAG = re.compile(r"release/(\d+)")
TODO = (
    'Deploy the CloudKit schema as the "Release" section of CLAUDE.md says, '
    "then start a new run with schema_deployed ticked."
)


class GitError(Exception):
    pass


def git(cwd, *args, ok=(0,)):
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if result.returncode not in ok:
        detail = " ".join(result.stderr.split()) or f"exit code {result.returncode}"
        raise GitError(f"git {args[0]} failed: {detail}")
    return result


def newest_marked_tag(cwd):
    """The marked release tag with the highest build number, or None. Lightweight tags have no tag message."""
    listing = git(cwd, "for-each-ref", "--format=%(objecttype) %(refname:strip=2)", "refs/tags/release/").stdout
    builds = []
    for line in listing.splitlines():
        kind, name = line.split(" ", 1)
        match = TAG.fullmatch(name)
        if kind == "tag" and match:
            builds.append((int(match.group(1)), name))
    for _, name in sorted(builds, reverse=True):
        message = git(cwd, "for-each-ref", "--format=%(contents)", f"refs/tags/{name}").stdout
        if MARKER in (line.strip() for line in message.splitlines()):
            return name
    return None


def model_changed(cwd, tag):
    return git(cwd, "diff", "--quiet", tag, "HEAD", "--", MODEL, ok=(0, 1)).returncode == 1


def main(env=None, cwd=None):
    env = os.environ if env is None else env
    ticked = env.get("SCHEMA_DEPLOYED", "false") == "true"
    tag, changed, error = None, True, None
    try:
        tag = newest_marked_tag(cwd)
        if tag is not None:
            changed = model_changed(cwd, tag)
    except GitError as e:
        error = str(e)

    if error is not None:
        reason = f"The schema check could not read the repository: {error}."
    elif tag is None:
        reason = "No release tag has the schema check, so the Core Data model counts as changed."
    elif changed:
        reason = f"The Core Data model ({MODEL}) changed since {tag}."
    else:
        print(f"::notice::The Core Data model is the same as at {tag}. The schema check passes.")
        return 0

    if ticked:
        print(f"::notice::schema_deployed is ticked, so the schema check passes, although {lowercase_first(reason)}")
        return 0
    print(f"::error::{reason} {TODO}")
    return 1


def lowercase_first(text):
    return text[0].lower() + text[1:]


if __name__ == "__main__":
    sys.exit(main())
