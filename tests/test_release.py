"""Exercise publication boundaries without storing any private examples."""

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "release", Path(__file__).resolve().parents[1] / "scripts" / "check_release.py"
)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def svg(body="", attributes=""):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" ' + attributes + ">"
        '<title id="title">Synthetic example</title>'
        '<desc id="description">Entirely synthetic tree and traits.</desc>' + body + "</svg>"
    )


class SvgBoundaryTests(unittest.TestCase):
    def test_checked_in_gallery_figures_are_accepted(self):
        for name in sorted(release.SVG_FILES):
            with self.subTest(name=name):
                content = (release.ROOT / name).read_text(encoding="utf-8")
                self.assertEqual(release.check_svg(content), [])

    def test_clip_rule_support_is_limited_to_static_valid_values(self):
        for value in ("nonzero", "evenodd"):
            with self.subTest(value=value):
                self.assertEqual(release.check_svg(svg(f'<path clip-rule="{value}"/>')), [])
        for value in ("inherit", "invalid", "url(#shape)"):
            with self.subTest(value=value):
                self.assertTrue(release.check_svg(svg(f'<path clip-rule="{value}"/>')))

    def test_accepts_static_cairo_glyphs_and_accessible_provenance(self):
        content = svg(
            '<defs><symbol id="glyph0-1" overflow="visible">'
            '<path d="M 0 0 L 1 1" style="stroke:none;fill-opacity:1;"/>'
            '</symbol><clipPath id="clip1"><rect width="10" height="10"/>'
            '</clipPath></defs><g clip-path="url(#clip1)">'
            '<use xlink:href="#glyph0-1" x="1" y="2"/></g>',
            'role="img" aria-labelledby="title description"',
        )
        self.assertEqual(release.check_svg(content), [])

    def test_requires_namespace_and_two_plain_provenance_labels(self):
        for content in (
            svg().replace('xmlns="http://www.w3.org/2000/svg"', ""),
            svg().replace("Synthetic example", "Example"),
            svg().replace("Entirely synthetic tree and traits.", "Unspecified origin"),
            svg().replace('<title id="title">Synthetic example</title>', ""),
            svg('<title>Synthetic extra title</title>'),
        ):
            with self.subTest(content=content):
                self.assertTrue(release.check_svg(content))

    def test_rejects_active_embedded_or_external_elements(self):
        for body in (
            "<script>alert(1)</script>",
            '<image href="data:image/png;base64,AAAA"/>',
            '<image href="https://example.invalid/figure.png"/>',
            '<use href="https://example.invalid/figure.svg#shape"/>',
            '<use href="//example.invalid/figure.svg#shape"/>',
            '<foreignObject><div>Hidden</div></foreignObject>',
            '<animate attributeName="opacity" values="1;0"/>',
            '<path onclick="alert(1)" d="M0 0"/>',
        ):
            with self.subTest(body=body):
                self.assertTrue(release.check_svg(svg(body)))

    def test_rejects_hidden_and_unapproved_text(self):
        for body in (
            '<g style="display:none"><path d="M0 0"/></g>',
            '<g visibility="hidden"/>',
            '<g opacity="0"/>',
            '<g style="fill-opacity:0;"/>',
            '<text>Unreviewed label</text>',
            '<defs><desc>Synthetic concealed label</desc></defs>',
            '<metadata>Unreviewed metadata</metadata>',
            '<g>Unreviewed content</g>',
            '<!-- Unreviewed comment -->',
        ):
            with self.subTest(body=body):
                self.assertTrue(release.check_svg(svg(body)))

    def test_rejects_declarations_entities_and_processing_instructions(self):
        for prefix in (
            '<!DOCTYPE svg [<!ENTITY label "Unreviewed">]>',
            '<!DOCTYPE svg SYSTEM "https://example.invalid/figure.dtd">',
            '<?xml-stylesheet href="https://example.invalid/theme.css"?>',
        ):
            with self.subTest(prefix=prefix):
                self.assertTrue(release.check_svg(prefix + svg()))

    def test_rejects_css_resources_and_unresolved_references(self):
        for body in (
            '<g style="clip-path:url(https://example.invalid/clip.svg#shape)"/>',
            '<g style="fill:url(#paint)"/>',
            '<g style="stroke:expression(alert(1))"/>',
            '<g style="unknown:1"/>',
            '<g style="fill:/**/none"/>',
            '<use href="#missing"/>',
            '<path id="same"/><path id="same"/>',
        ):
            with self.subTest(body=body):
                self.assertTrue(release.check_svg(svg(body)))

    def test_malformed_xml_is_reported_without_raising(self):
        self.assertTrue(release.check_svg(svg("<g>")))


class ReleaseBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.root_patch = patch.object(release, "ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.addCleanup(self.directory.cleanup)

    def write(self, name, content):
        destination = self.root / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            destination.write_bytes(content)
        else:
            destination.write_text(content, encoding="utf-8")

    def manifest(self, *files):
        self.write("release-files.txt", "\n".join(("release-files.txt", *files)) + "\n")

    def test_accepts_only_explicit_software_and_reviewed_figure_paths(self):
        figure = "docs/figures/synthetic_tree.svg"
        self.write("README.md", "Research workflow\n")
        self.write(figure, svg('<path d="M0 0 L1 1"/>'))
        self.manifest("README.md", figure)
        self.assertEqual(release.check(), [])

    def test_unexpected_raw_file_fails_even_when_not_allowlisted(self):
        self.manifest()
        self.write("raw.csv", "value\n1\n")
        self.assertTrue(release.check())

    def test_only_the_two_reviewed_svg_paths_are_permitted(self):
        self.write("other.svg", svg())
        self.manifest("other.svg")
        self.assertTrue(release.check())

    def test_allowlisting_raw_file_does_not_bypass_type_boundary(self):
        self.write("traits.csv", "value\n1\n")
        self.manifest("traits.csv")
        self.assertTrue(release.check())

    def test_traversal_and_duplicate_entries_fail(self):
        self.manifest("../README.md")
        self.assertIn("Invalid allowlist path or file type.", release.check())
        self.manifest("README.md", "README.md")
        self.assertIn("Allowlist is empty or has duplicate entries.", release.check())

    def test_missing_file_fails(self):
        self.manifest("README.md")
        self.assertTrue(release.check())

    def test_size_binary_and_encoding_limits_apply_to_reviewed_figures(self):
        figure = "docs/figures/synthetic_tree.svg"
        self.manifest(figure)
        for content, expected in (
            (svg(" " * 500_001), "Oversized or binary file"),
            (b"\x00", "Oversized or binary file"),
            (b"\xff", "Non-UTF-8 file"),
        ):
            with self.subTest(size=len(content)):
                self.write(figure, content)
                self.assertTrue(any(expected in problem for problem in release.check()))

    def test_sensitive_patterns_are_reported_without_echoing_values(self):
        # Assemble artificial canaries at runtime so none is a published identifier.
        canaries = (
            "research" + "@" + "example" + "." + "invalid",
            "C" + ":" + chr(92) + "Users" + chr(92) + "example",
            "gh" + "p_" + "x" * 24,
        )
        self.manifest("README.md")
        for canary in canaries:
            with self.subTest(category=canaries.index(canary)):
                self.write("README.md", canary)
                problems = release.check()
                self.assertTrue(problems)
                self.assertNotIn(canary, "\n".join(problems))

    def test_tracked_files_must_match_manifest_and_audited_commit(self):
        self.manifest()
        with patch.object(release, "git", side_effect=[b"release-files.txt\x00", b""]):
            self.assertEqual(release.check(tracked=True), [])
        with patch.object(release, "git", side_effect=[b"extra.csv\x00", b""]):
            self.assertTrue(release.check(tracked=True))
        with patch.object(release, "git", side_effect=[b"release-files.txt\x00", b"README.md\n"]):
            self.assertTrue(release.check(tracked=True))


if __name__ == "__main__":
    unittest.main()
