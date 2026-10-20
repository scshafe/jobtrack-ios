"""Swift-free checks of the iOS project: the XcodeGen spec, the Swift package
layout and what git holds. They run on Linux; the app is built on a Mac."""

import re
import subprocess
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BUNDLE_ID = "com.scshafe.jobtrack"


def git_files():
    """Tracked plus untracked-but-not-ignored files: what a commit would hold."""
    out = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT, check=True, capture_output=True, text=True,
    ).stdout
    return [line for line in out.splitlines() if line]


def ignored(path):
    return subprocess.run(
        ["git", "check-ignore", "-q", "--no-index", path], cwd=ROOT,
    ).returncode == 0


def load(name):
    with open(ROOT / name, encoding="utf-8") as fh:
        return yaml.safe_load(fh)


class XcodeGenSpec(unittest.TestCase):
    def setUp(self):
        self.spec = load("project.yml")

    def test_identity_and_platform(self):
        self.assertEqual(self.spec["name"], "Jobtrack")
        self.assertEqual(self.spec["options"]["deploymentTarget"]["iOS"], "26.0")
        app = self.spec["targets"]["Jobtrack"]
        self.assertEqual(app["type"], "application")
        self.assertEqual(app["platform"], "iOS")
        self.assertEqual(app["settings"]["base"]["PRODUCT_BUNDLE_IDENTIFIER"], BUNDLE_ID)

    def test_unsigned_in_git(self):
        # Signing belongs in the ignored project.local.yml, never here.
        self.assertEqual(self.spec["settings"]["base"]["DEVELOPMENT_TEAM"], "")

    def test_sources_exist(self):
        for name, target in self.spec["targets"].items():
            for source in target.get("sources", []):
                path = source["path"] if isinstance(source, dict) else source
                with self.subTest(target=name, path=path):
                    self.assertTrue((ROOT / path).is_dir(), path)
                    self.assertTrue(any((ROOT / path).rglob("*.swift")), path)

    def test_packages_exist_and_are_used(self):
        packages = self.spec.get("packages", {})
        for name, package in packages.items():
            with self.subTest(package=name):
                self.assertTrue((ROOT / package["path"] / "Package.swift").is_file())
        used = {
            dep["package"]
            for target in self.spec["targets"].values()
            for dep in target.get("dependencies", [])
            if "package" in dep
        }
        self.assertEqual(used, set(packages))

    def test_generated_info_plist_is_ignored(self):
        for name, target in self.spec["targets"].items():
            info = target.get("info", {}).get("path")
            if info:
                with self.subTest(target=name):
                    self.assertTrue(ignored(info), f"{info} is generated: ignore it")

    def test_schemes_name_targets(self):
        targets = set(self.spec["targets"])
        for name, scheme in self.spec.get("schemes", {}).items():
            with self.subTest(scheme=name):
                self.assertLessEqual(set(scheme["build"]["targets"]), targets)

    def test_local_example_includes_the_spec(self):
        example = load("project.local.yml.example")
        self.assertIn("project.yml", example["include"])
        self.assertTrue(ignored("project.local.yml"))


class SwiftPackage(unittest.TestCase):
    def test_targets_have_directories(self):
        manifest = (ROOT / "JobtrackKit" / "Package.swift").read_text(encoding="utf-8")
        targets = re.findall(r'\.target\(name: "([^"]+)"', manifest)
        tests = re.findall(r'\.testTarget\(name: "([^"]+)"', manifest)
        self.assertTrue(targets and tests)
        for name in targets:
            self.assertTrue(any((ROOT / "JobtrackKit/Sources" / name).glob("*.swift")), name)
        for name in tests:
            self.assertTrue(any((ROOT / "JobtrackKit/Tests" / name).glob("*.swift")), name)

    def test_kit_has_no_ui_imports(self):
        for path in (ROOT / "JobtrackKit/Sources").rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            with self.subTest(path=path.name):
                self.assertNotRegex(text, r"(?m)^import (SwiftUI|UIKit)\b")


class WhatGitHolds(unittest.TestCase):
    def test_no_generated_or_private_files(self):
        bad = re.compile(
            r"(\.xcodeproj/|\.xcworkspace/|xcuserdata/|DerivedData/|(^|/)\.build/"
            r"|(^|/)project\.local\.yml$|(^|/)Info\.plist$|\.p8$|\.p12$|\.mobileprovision$|\.eml$|\.sqlite3?$|\.db$)"
        )
        self.assertEqual([f for f in git_files() if bad.search(f)], [])

    def test_no_tailnet_name(self):
        # Public repository: the tailnet is written <tailnet>, never named.
        named = []
        for f in git_files():
            path = ROOT / f
            if not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            if re.search(r"[a-z0-9-]+\.ts\.net\b", text):
                named.append(f)
        self.assertEqual(named, [])

    def test_swift_only_where_expected(self):
        stray = [
            f for f in git_files()
            if f.endswith(".swift") and not f.startswith(("Jobtrack/", "JobtrackKit/"))
        ]
        self.assertEqual(stray, [])


if __name__ == "__main__":
    unittest.main()
