#!/usr/bin/env python3
"""Check the explicit publication boundary; no private denylist is distributed."""

import argparse
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
SPECIAL = {".gitattributes", ".gitignore", "release-files.txt"}
SUFFIXES = {".R", ".md", ".py", ".yml"}
PATTERNS = {
    "personal email address": re.compile(
        r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.I
    ),
    "private absolute path": re.compile(r"(?i)(?:(?<![a-z0-9])[a-z]:[\\/]|/(?:Users|home)/)"),
    "credential token": re.compile(
        r"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
        r"AKIA[A-Z0-9]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)"
    ),
}


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def check(tracked=False):
    problems = []
    manifest = ROOT / "release-files.txt"
    entries = manifest.read_text(encoding="utf-8").splitlines()
    if not entries or len(entries) != len(set(entries)):
        problems.append("Allowlist is empty or has duplicate entries.")
    allowed = set(entries)
    for name in sorted(allowed):
        path = PurePosixPath(name)
        if (not name or path.is_absolute() or ".." in path.parts or
                "\\" in name or str(path) != name or
                (name not in SPECIAL and path.suffix not in SUFFIXES)):
            problems.append("Invalid allowlist path or file type.")
            continue
        file = ROOT / name
        if not file.is_file() or any(p.is_symlink() for p in [file, *file.parents]):
            problems.append(f"Missing file or symlink: {name}")
            continue
        raw = file.read_bytes()
        if len(raw) > 500_000 or b"\x00" in raw:
            problems.append(f"Oversized or binary file: {name}")
            continue
        try:
            content = raw.decode("utf-8")
        except UnicodeDecodeError:
            problems.append(f"Non-UTF-8 file: {name}")
            continue
        for category, pattern in PATTERNS.items():
            if pattern.search(content):
                # Do not echo the matching value into a CI log.
                problems.append(f"Potential {category}: {name}")

    if tracked:
        tracked_names = set(git("ls-files", "-z").decode("utf-8").strip("\x00").split("\x00"))
        if tracked_names != allowed:
            problems.append("Git tracked files differ from the publication allowlist.")
        if git("diff", "--name-only", "HEAD", "--").strip():
            problems.append("Tracked files differ from the audited commit.")
    else:
        names = {
            p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*")
            if p.is_file() and not any(
                part in {".git", "artifacts", "__pycache__"}
                for part in p.relative_to(ROOT).parts
            )
        }
        if names != allowed:
            problems.append("Working directory files differ from the publication allowlist.")

    return problems


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tracked", action="store_true", help="Also verify Git's tracked file set")
    args = parser.parse_args()
    try:
        errors = check(args.tracked)
    except (OSError, subprocess.CalledProcessError, UnicodeError):
        errors = ["Release check could not read the manifest or Git state."]
    if errors:
        print("Publication check FAILED:")
        for error in errors:
            print(f"- {error}")
        sys.exit(1)
    print("Publication check passed: only allowlisted software and documentation.")
