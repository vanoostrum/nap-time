"""Tests for release_check.py. Run: python3 -m unittest discover -s scripts -p 'test_*.py'"""

import contextlib
import io
import json
import pathlib
import plistlib
import struct
import tempfile
import unittest
from unittest import mock
import zlib

from release_check import (
    APP,
    WIDGET,
    check_archive,
    check_archived_entitlements,
    check_entitlements,
    check_icon,
    committed_icon,
    main,
    marketing_version,
)

REPO = pathlib.Path(__file__).resolve().parent.parent


def app_info(**changes):
    info = {
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "42",
        "ITSAppUsesNonExemptEncryption": False,
        "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconName": "AppIcon"}},
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "UIRequiresFullScreen": True,
    }
    info.update(changes)
    return {k: v for k, v in info.items() if v is not None}


def widget_info(**changes):
    info = {"CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "42"}
    info.update(changes)
    return {k: v for k, v in info.items() if v is not None}


def app_entitlements(**changes):
    ents = {
        "aps-environment": "production",
        "com.apple.developer.icloud-container-environment": "Production",
        "com.apple.developer.icloud-container-identifiers": ["iCloud.nl.clearblocks.naptime"],
        "com.apple.developer.icloud-services": ["CloudKit"],
        "com.apple.security.application-groups": ["group.nl.clearblocks.naptime"],
        "get-task-allow": False,
        # Keys that the check does not read pass through.
        "application-identifier": "2SUL28U5Y7.nl.clearblocks.naptime",
    }
    ents.update(changes)
    return {k: v for k, v in ents.items() if v is not None}


def widget_entitlements(**changes):
    ents = {"com.apple.security.application-groups": ["group.nl.clearblocks.naptime"], "get-task-allow": False}
    ents.update(changes)
    return {k: v for k, v in ents.items() if v is not None}


def png(width=1024, height=1024, colour_type=2, extra_chunks=()):
    """A minimal PNG: the signature, IHDR, the given chunks, and IEND. The check reads only the chunks."""

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0)
    body = chunk(b"IHDR", ihdr)
    for kind, data in extra_chunks:
        body += chunk(kind, data)
    body += chunk(b"IDAT", zlib.compress(b"")) + chunk(b"IEND", b"")
    return b"\x89PNG\r\n\x1a\n" + body


class ArchiveTests(unittest.TestCase):
    def test_a_good_archive_passes(self):
        self.assertEqual(check_archive(app_info(), widget_info(), "1.0.0", "42"), [])

    def test_the_build_number_is_optional(self):
        self.assertEqual(check_archive(app_info(), widget_info(), "1.0.0"), [])

    def test_each_wrong_value_fails_and_names_its_key(self):
        cases = [
            (app_info(CFBundleShortVersionString="0.1.0"), widget_info(), "CFBundleShortVersionString"),
            (app_info(CFBundleVersion="7"), widget_info(), "CFBundleVersion"),
            (app_info(ITSAppUsesNonExemptEncryption=True), widget_info(), "ITSAppUsesNonExemptEncryption"),
            (
                app_info(CFBundleIcons={"CFBundlePrimaryIcon": {"CFBundleIconName": "Other"}}),
                widget_info(),
                "CFBundleIconName",
            ),
            (app_info(), widget_info(CFBundleShortVersionString="0.1.0"), "CFBundleShortVersionString"),
            (app_info(), widget_info(CFBundleVersion="1"), "CFBundleVersion"),
        ]
        for app, widget, key in cases:
            with self.subTest(key=key, app=app, widget=widget):
                errors = check_archive(app, widget, "1.0.0", "42")
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(key, errors[0])

    def test_each_missing_value_fails_and_names_its_key(self):
        cases = [
            (app_info(CFBundleShortVersionString=None), widget_info(), "CFBundleShortVersionString"),
            (app_info(CFBundleVersion=None), widget_info(), "CFBundleVersion"),
            (app_info(ITSAppUsesNonExemptEncryption=None), widget_info(), "ITSAppUsesNonExemptEncryption"),
            (app_info(CFBundleIcons=None), widget_info(), "CFBundleIconName"),
            (app_info(), widget_info(CFBundleShortVersionString=None), "CFBundleShortVersionString"),
            (app_info(), widget_info(CFBundleVersion=None), "CFBundleVersion"),
        ]
        for app, widget, key in cases:
            with self.subTest(key=key, app=app, widget=widget):
                errors = check_archive(app, widget, "1.0.0", "42")
                self.assertTrue(errors)
                self.assertTrue(any(key in e for e in errors), errors)

    def test_fewer_than_four_orientations_need_full_screen(self):
        # App Store Connect rejects such an upload with error 90474 (Release run 3).
        for value in [None, False]:
            with self.subTest(UIRequiresFullScreen=value):
                errors = check_archive(app_info(UIRequiresFullScreen=value), widget_info(), "1.0.0", "42")
                self.assertEqual(len(errors), 1, errors)
                self.assertIn("UIRequiresFullScreen", errors[0])
                self.assertIn("UIInterfaceOrientationPortrait", errors[0])

    def test_all_four_orientations_need_no_full_screen(self):
        every = [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
        ]
        info = app_info(UISupportedInterfaceOrientations=every, UIRequiresFullScreen=None)
        self.assertEqual(check_archive(info, widget_info(), "1.0.0", "42"), [])

    def test_a_widget_error_names_the_widget(self):
        errors = check_archive(app_info(), widget_info(CFBundleVersion="1"), "1.0.0", "42")
        self.assertIn(WIDGET, errors[0])

    def test_the_version_comes_from_project_yml(self):
        self.assertEqual(marketing_version(REPO / "project.yml"), "1.0.0")

    def test_the_archive_command_reads_the_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = pathlib.Path(tmp) / "NapTime.xcarchive"
            app = archive / "Products/Applications" / APP
            widget = app / "PlugIns" / WIDGET
            widget.mkdir(parents=True)
            (app / "Info.plist").write_bytes(plistlib.dumps(app_info(), fmt=plistlib.FMT_BINARY))
            (widget / "Info.plist").write_bytes(plistlib.dumps(widget_info(), fmt=plistlib.FMT_BINARY))
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(main(["archive", str(archive), "--build", "42"]), 0)
            with contextlib.redirect_stdout(out):
                self.assertEqual(main(["archive", str(archive), "--build", "43"]), 1)
            self.assertIn("CFBundleVersion", out.getvalue())


class EntitlementTests(unittest.TestCase):
    def test_good_entitlements_pass(self):
        self.assertEqual(check_entitlements(app_entitlements(), widget_entitlements()), [])

    def test_each_wrong_app_value_fails_and_names_the_bundle_key_and_value(self):
        cases = [
            ("aps-environment", "development"),
            ("com.apple.developer.icloud-container-environment", "Development"),
            ("get-task-allow", True),
            ("com.apple.developer.icloud-container-identifiers", ["iCloud.nl.clearblocks.other"]),
            ("com.apple.developer.icloud-services", ["CloudDocuments"]),
            ("com.apple.security.application-groups", ["group.nl.clearblocks.other"]),
        ]
        for key, value in cases:
            with self.subTest(key=key):
                errors = check_entitlements(app_entitlements(**{key: value}), widget_entitlements())
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(APP, errors[0])
                self.assertIn(key, errors[0])
                self.assertIn(repr(value), errors[0])

    def test_each_missing_app_value_fails_and_names_the_bundle_and_key(self):
        for key in [
            "aps-environment",
            "com.apple.developer.icloud-container-environment",
            "get-task-allow",
            "com.apple.developer.icloud-container-identifiers",
            "com.apple.developer.icloud-services",
            "com.apple.security.application-groups",
        ]:
            with self.subTest(key=key):
                errors = check_entitlements(app_entitlements(**{key: None}), widget_entitlements())
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(APP, errors[0])
                self.assertIn(key, errors[0])
                self.assertIn("missing", errors[0])

    def test_each_wrong_or_missing_widget_value_fails_and_names_the_widget(self):
        cases = [
            ("get-task-allow", True),
            ("get-task-allow", None),
            ("com.apple.security.application-groups", ["group.nl.clearblocks.other"]),
            ("com.apple.security.application-groups", None),
        ]
        for key, value in cases:
            with self.subTest(key=key, value=value):
                errors = check_entitlements(app_entitlements(), widget_entitlements(**{key: value}))
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(WIDGET, errors[0])
                self.assertIn(key, errors[0])
                self.assertIn("missing" if value is None else repr(value), errors[0])

    def test_an_empty_signature_fails_for_every_key(self):
        errors = check_entitlements({}, {})
        self.assertEqual(len(errors), 8, errors)

    def test_the_entitlements_command_fails_with_no_ipa(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main(["entitlements", "/no/such/NapTime.ipa"]), 1)


class ArchivedEntitlementTests(unittest.TestCase):
    """The ad-hoc signed archive must carry the entitlements, or the export drops them (first Release run)."""

    def development(self, **changes):
        return app_entitlements(
            **{
                "aps-environment": "development",
                "com.apple.developer.icloud-container-environment": None,
                "get-task-allow": None,
                **changes,
            }
        )

    def test_the_entitlements_of_project_yml_pass(self):
        self.assertEqual(check_archived_entitlements(self.development(), widget_entitlements(**{"get-task-allow": None})), [])

    def test_an_unsigned_archive_fails_for_every_key(self):
        errors = check_archived_entitlements({}, {})
        self.assertEqual(len(errors), 5, errors)
        self.assertTrue(any(WIDGET in e for e in errors), errors)

    def test_each_missing_or_wrong_key_fails_and_names_the_bundle_and_key(self):
        for key in [
            "aps-environment",
            "com.apple.developer.icloud-container-identifiers",
            "com.apple.developer.icloud-services",
            "com.apple.security.application-groups",
        ]:
            with self.subTest(key=key):
                errors = check_archived_entitlements(self.development(**{key: None}), widget_entitlements())
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(APP, errors[0])
                self.assertIn(key, errors[0])
        errors = check_archived_entitlements(
            self.development(), widget_entitlements(**{"com.apple.security.application-groups": ["group.other"]})
        )
        self.assertEqual(len(errors), 1, errors)
        self.assertIn(WIDGET, errors[0])

    def test_the_archive_command_checks_the_signature_only_when_asked(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch("release_check.signed_entitlements", return_value={}):
            archive = pathlib.Path(tmp) / "NapTime.xcarchive"
            app = archive / "Products/Applications" / APP
            widget = app / "PlugIns" / WIDGET
            widget.mkdir(parents=True)
            (app / "Info.plist").write_bytes(plistlib.dumps(app_info()))
            (widget / "Info.plist").write_bytes(plistlib.dumps(widget_info()))
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(main(["archive", str(archive), "--build", "42"]), 0)
                self.assertEqual(main(["archive", str(archive), "--build", "42", "--signed"]), 1)
            self.assertIn("aps-environment is missing", out.getvalue())


class IconTests(unittest.TestCase):
    def write(self, data):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = pathlib.Path(tmp.name) / "icon.png"
        path.write_bytes(data)
        return path

    def test_an_opaque_1024_png_passes(self):
        for colour_type in [0, 2, 3]:
            with self.subTest(colour_type=colour_type):
                self.assertEqual(check_icon(self.write(png(colour_type=colour_type))), [])

    def test_another_size_fails(self):
        for width, height in [(512, 512), (1024, 1000), (2048, 2048)]:
            with self.subTest(size=(width, height)):
                errors = check_icon(self.write(png(width, height)))
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(f"{width}x{height}", errors[0])

    def test_a_colour_type_with_alpha_fails(self):
        for colour_type in [4, 6]:
            with self.subTest(colour_type=colour_type):
                errors = check_icon(self.write(png(colour_type=colour_type)))
                self.assertEqual(len(errors), 1, errors)
                self.assertIn("alpha", errors[0])

    def test_a_transparency_chunk_fails(self):
        errors = check_icon(self.write(png(colour_type=2, extra_chunks=[(b"tRNS", b"\x00\x00\x00\x00\x00\x00")])))
        self.assertEqual(len(errors), 1, errors)
        self.assertIn("tRNS", errors[0])

    def test_a_file_that_is_not_a_png_fails(self):
        self.assertEqual(len(check_icon(self.write(b"GIF89a"))), 1)

    def test_the_committed_icon_passes(self):
        path = committed_icon(REPO)
        self.assertEqual(path.name, json.loads(path.with_name("Contents.json").read_text())["images"][0]["filename"])
        self.assertEqual(check_icon(path), [])
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(main(["icon"]), 0)

    def test_the_committed_icon_is_the_settled_icon(self):
        # The placeholder has sky at the moon's point, so this fails until the settled icon is committed.
        pixel = rgb_pixels(committed_icon(REPO))
        for name, point, expected in [("moon", (358, 614), (0xE9, 0xC7, 0x7B)), ("sky", (20, 20), (0x07, 0x0B, 0x24))]:
            with self.subTest(name):
                actual = pixel(*point)
                self.assertTrue(
                    all(abs(a - e) <= 12 for a, e in zip(actual, expected)),
                    f"{name} at {point} is #{bytes(actual).hex()}, expected near #{bytes(expected).hex()}",
                )


def rgb_pixels(path):
    """Decode an 8-bit RGB PNG without interlace, and return a function from (x, y) to (r, g, b)."""
    data = pathlib.Path(path).read_bytes()
    offset, idat = 8, b""
    while offset < len(data):
        length, kind = struct.unpack(">I4s", data[offset : offset + 8])
        body = data[offset + 8 : offset + 8 + length]
        if kind == b"IHDR":
            width, height, depth, colour_type, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert (depth, colour_type, interlace) == (8, 2, 0), "expected 8-bit RGB without interlace"
        elif kind == b"IDAT":
            idat += body
        offset += 12 + length
    raw, stride = zlib.decompress(idat), width * 3
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, row = raw[start], bytearray(raw[start + 1 : start + 1 + stride])
        for i in range(stride):
            left = row[i - 3] if i >= 3 else 0
            up, up_left = previous[i], previous[i - 3] if i >= 3 else 0
            if kind == 1:
                row[i] = (row[i] + left) & 0xFF
            elif kind == 2:
                row[i] = (row[i] + up) & 0xFF
            elif kind == 3:
                row[i] = (row[i] + (left + up) // 2) & 0xFF
            elif kind == 4:
                p = left + up - up_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - up_left)
                row[i] = (row[i] + (left if pa <= pb and pa <= pc else up if pb <= pc else up_left)) & 0xFF
        rows.append(row)
        previous = row
    return lambda x, y: tuple(rows[y][x * 3 : x * 3 + 3])


if __name__ == "__main__":
    unittest.main()
