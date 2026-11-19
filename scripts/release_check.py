#!/usr/bin/env python3
"""Checks a Release build of Nap Time before it goes to TestFlight (CRAFT-76).

Usage:
  scripts/release_check.py archive <NapTime.xcarchive> [--build N] [--signed]
      The app's version is MARKETING_VERSION in project.yml, the widget has the app's version and build
      number, ITSAppUsesNonExemptEncryption is false, and the primary icon is AppIcon. `App (iOS)` and `Release`.
      With --signed, also the entitlements that the ad-hoc signature carries into the export. macOS only.
  scripts/release_check.py entitlements <NapTime.ipa>
      The signed entitlements of the app and the widget are the ones for production. macOS only: reads
      them with codesign. `Release`, before the upload.
  scripts/release_check.py icon [<png>]
      The icon is a 1024x1024 PNG with no alpha. With no path, the PNG that AppIcon's Contents.json names.

Exits 0 when the check passes. Else prints one `FAIL:` line for each wrong or missing value, and exits 1.
"""

import argparse
import json
import pathlib
import plistlib
import re
import struct
import subprocess
import sys
import tempfile
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
APP = "NapTime.app"
WIDGET = "NapTimeWidget.appex"
ICON_SET = "App/Assets.xcassets/AppIcon.appiconset"
ICON_SIZE = 1024

GROUP = ["group.nl.clearblocks.naptime"]
# The identifiers of ADR 0004, and the production values that the App Store export must set.
APP_ENTITLEMENTS = {
    "aps-environment": "production",
    "com.apple.developer.icloud-container-environment": "Production",
    "com.apple.developer.icloud-container-identifiers": ["iCloud.nl.clearblocks.naptime"],
    "com.apple.developer.icloud-services": ["CloudKit"],
    "com.apple.security.application-groups": GROUP,
    "get-task-allow": False,
}
WIDGET_ENTITLEMENTS = {"com.apple.security.application-groups": GROUP, "get-task-allow": False}

MISSING = object()


def compare(bundle, actual, expected):
    """One error for each key of `expected` whose value in `actual` is missing or different."""
    errors = []
    for key, want in expected.items():
        got = actual.get(key, MISSING)
        if got is MISSING:
            errors.append(f"{bundle}: {key} is missing, expected {want!r}")
        elif got != want:
            errors.append(f"{bundle}: {key} is {got!r}, expected {want!r}")
    return errors


def marketing_version(project_yml):
    match = re.search(r"^\s*MARKETING_VERSION:\s*\"?([^\"\s]+)\"?\s*$", project_yml.read_text(), re.MULTILINE)
    if not match:
        raise ValueError(f"No MARKETING_VERSION in {project_yml}")
    return match.group(1)


def check_archive(app_info, widget_info, version, build=None):
    """The errors in the Info.plist of the app and of the widget in a Release archive."""
    expected = {"CFBundleShortVersionString": version, "ITSAppUsesNonExemptEncryption": False}
    if build is not None:
        expected["CFBundleVersion"] = build
    errors = compare(APP, app_info, expected)
    icon = app_info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {}).get("CFBundleIconName", MISSING)
    if icon is MISSING:
        errors.append(f"{APP}: CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName is missing, expected 'AppIcon'")
    elif icon != "AppIcon":
        errors.append(f"{APP}: CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName is {icon!r}, expected 'AppIcon'")
    # The widget must ship with the app's version and build number, or App Store Connect rejects the upload.
    widget_expected = {"CFBundleShortVersionString": version}
    app_build = build if build is not None else app_info.get("CFBundleVersion")
    if app_build is not None:
        widget_expected["CFBundleVersion"] = app_build
    elif "CFBundleVersion" not in widget_info:
        errors.append(f"{WIDGET}: CFBundleVersion is missing")
    return errors + compare(WIDGET, widget_info, widget_expected)


def check_entitlements(app, widget):
    """The errors in the signed entitlements of the app and of the widget."""
    return compare(APP, app, APP_ENTITLEMENTS) + compare(f"{APP}/PlugIns/{WIDGET}", widget, WIDGET_ENTITLEMENTS)


def check_archived_entitlements(app, widget):
    """The errors in the ad-hoc signature of the archive. The export keeps only these keys, and sets the
    production values itself, so aps-environment only has to be there."""
    expected = {k: v for k, v in APP_ENTITLEMENTS.items() if "environment" not in k and k != "get-task-allow"}
    errors = compare(APP, app, expected)
    if "aps-environment" not in app:
        errors.append(f"{APP}: aps-environment is missing")
    widget_expected = {k: v for k, v in WIDGET_ENTITLEMENTS.items() if k != "get-task-allow"}
    return errors + compare(f"{APP}/PlugIns/{WIDGET}", widget, widget_expected)


def check_icon(path):
    """The errors of an App Store icon PNG: not 1024x1024, or any transparency."""
    data = pathlib.Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return [f"{path}: not a PNG file"]
    width, height, _, colour_type = struct.unpack(">IIBB", data[16:26])
    errors = []
    if (width, height) != (ICON_SIZE, ICON_SIZE):
        errors.append(f"{path}: size is {width}x{height}, expected {ICON_SIZE}x{ICON_SIZE}")
    if colour_type in (4, 6):
        errors.append(f"{path}: colour type {colour_type} has an alpha channel, expected no alpha")
    offset = 8
    while offset + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[offset : offset + 8])
        if kind == b"tRNS":
            errors.append(f"{path}: has a tRNS chunk, which makes pixels transparent, expected no alpha")
        if kind == b"IEND":
            break
        offset += 12 + length
    return errors


def committed_icon(repo=REPO):
    """The PNG that AppIcon's Contents.json names."""
    icon_set = repo / ICON_SET
    images = json.loads((icon_set / "Contents.json").read_text())["images"]
    return icon_set / images[0]["filename"]


def read_plist(path):
    with open(path, "rb") as f:
        return plistlib.load(f)


def signed_entitlements(bundle):
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", "-", "--xml", str(bundle)], capture_output=True, check=False
    )
    if result.returncode != 0:
        raise RuntimeError(f"codesign failed on {bundle}: {result.stderr.decode(errors='replace').strip()}")
    return plistlib.loads(result.stdout) if result.stdout.strip() else {}


def run_entitlements(ipa):
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(ipa) as z:
            z.extractall(tmp)
        app = pathlib.Path(tmp) / "Payload" / APP
        return check_entitlements(signed_entitlements(app), signed_entitlements(app / "PlugIns" / WIDGET))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="check", required=True)
    archive = sub.add_parser("archive")
    archive.add_argument("path", type=pathlib.Path)
    archive.add_argument("--build")
    archive.add_argument("--project", type=pathlib.Path, default=REPO / "project.yml")
    archive.add_argument("--signed", action="store_true")
    entitlements = sub.add_parser("entitlements")
    entitlements.add_argument("ipa", type=pathlib.Path)
    icon = sub.add_parser("icon")
    icon.add_argument("png", type=pathlib.Path, nargs="?")
    args = parser.parse_args(argv)

    try:
        if args.check == "archive":
            app = args.path / "Products/Applications" / APP
            errors = check_archive(
                read_plist(app / "Info.plist"),
                read_plist(app / "PlugIns" / WIDGET / "Info.plist"),
                marketing_version(args.project),
                args.build,
            )
            if args.signed:
                errors += check_archived_entitlements(
                    signed_entitlements(app), signed_entitlements(app / "PlugIns" / WIDGET)
                )
        elif args.check == "entitlements":
            errors = run_entitlements(args.ipa)
        else:
            errors = check_icon(args.png or committed_icon())
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile, plistlib.InvalidFileException) as e:
        errors = [str(e)]

    for error in errors:
        print(f"FAIL: {error}")
    if errors:
        return 1
    print(f"release_check {args.check}: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
