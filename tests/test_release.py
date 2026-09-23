"""Exercise publication boundaries without storing any private examples."""

import importlib.util
import struct
import tempfile
import unittest
import zlib
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


def png_chunk(kind, payload=b""):
    return (struct.pack(">I", len(payload)) + kind + payload +
            struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))


def png_fixture(*, dimensions=(2, 2), encoding=(8, 2, 0, 0, 0),
                before=b"", image_data=None, after=b""):
    if image_data is None:
        image_data = zlib.compress(b"\x00" * ((1 + dimensions[0] * 3) * dimensions[1]))
    return (release.PNG_SIGNATURE +
            png_chunk(b"IHDR", struct.pack(">IIBBBBB", *dimensions, *encoding)) +
            before + png_chunk(b"IDAT", image_data) + png_chunk(b"IEND") + after)


class PngBoundaryTests(unittest.TestCase):
    name = "docs/figures/method_tree.png"

    def test_checked_in_methods_figures_are_accepted(self):
        for name in release.PNG_FILES:
            with self.subTest(name=name):
                self.assertEqual(release.check_png((release.ROOT / name).read_bytes(), name), [])

    def check(self, content, name=None):
        with patch.object(release, "PNG_FILES", {self.name: (2, 2)}):
            return release.check_png(content, name or self.name)

    def test_accepts_only_reviewed_encoding_and_dimensions(self):
        self.assertEqual(self.check(png_fixture()), [])
        self.assertEqual(self.check(png_fixture(
            before=png_chunk(b"pHYs", struct.pack(">IIB", 9449, 9449, 1)))), [])
        for content in (
            png_fixture(dimensions=(3, 2)), png_fixture(encoding=(16, 2, 0, 0, 0)),
            png_fixture(encoding=(8, 6, 0, 0, 0)), png_fixture(encoding=(8, 2, 0, 0, 1)),
        ):
            with self.subTest(content=content[:29]):
                self.assertTrue(self.check(content))

    def test_rejects_unreviewed_paths_signature_and_oversized_files(self):
        self.assertTrue(self.check(png_fixture(), "docs/figures/other.png"))
        self.assertTrue(self.check(b"not a png"))
        self.assertTrue(self.check(png_fixture() + b"x" * 2_000_000))

    def test_rejects_text_exif_animation_unknown_chunks_and_bad_resolution(self):
        for kind in (b"tEXt", b"iTXt", b"zTXt", b"eXIf", b"acTL", b"tIME", b"zzZZ"):
            with self.subTest(kind=kind):
                self.assertTrue(self.check(png_fixture(before=png_chunk(kind, b"payload"))))
        for payload in (b"", struct.pack(">IIB", 1, 1, 2)):
            self.assertTrue(self.check(png_fixture(before=png_chunk(b"pHYs", payload))))

    def test_rejects_truncation_checksums_missing_end_and_trailing_bytes(self):
        original = png_fixture()
        corrupt = bytearray(original)
        corrupt[29] ^= 1
        for content in (
            original[:10], original[:-1], original[:-12], bytes(corrupt),
            original + b"concealed", original + original,
        ):
            with self.subTest(size=len(content)):
                self.assertTrue(self.check(content))

    def test_rejects_duplicate_headers_and_invalid_chunk_order(self):
        header = png_chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 2, 0, 0, 0))
        physics = png_chunk(b"pHYs", struct.pack(">IIB", 1, 1, 1))
        for content in (
            png_fixture(before=header), png_fixture(before=physics + physics),
            release.PNG_SIGNATURE + physics + png_fixture()[8:],
            png_fixture()[:-12] + physics + png_chunk(b"IEND"),
            release.PNG_SIGNATURE + header + png_chunk(b"IEND"),
        ):
            self.assertTrue(self.check(content))

    def test_decompression_is_bounded_and_requires_exact_pixel_payload(self):
        for compressed in (
            b"invalid", zlib.compress(b"\x00" * 13),
            zlib.compress(b"\x00" * 15), zlib.compress(b"\x00" * 1_000_000),
            zlib.compress(b"\x00" * 14) + b"concealed",
            zlib.compress(b"\x00" * 14) + zlib.compress(b"extra"),
            zlib.compress(b"\x00" * 14)[:-1],
            zlib.compress(b"\x05" + b"\x00" * 13),
        ):
            with self.subTest(size=len(compressed)):
                self.assertTrue(self.check(png_fixture(image_data=compressed)))


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

    def test_only_the_reviewed_svg_paths_are_permitted(self):
        self.write("other.svg", svg())
        self.manifest("other.svg")
        self.assertTrue(release.check())

    def test_png_allowlisting_cannot_bypass_the_reviewed_paths_or_structure(self):
        self.write("docs/figures/other.png", png_fixture())
        self.manifest("docs/figures/other.png")
        self.assertIn("Invalid allowlist path or file type.", release.check())
        (self.root / "docs/figures/other.png").unlink()
        name = "docs/figures/method_tree.png"
        self.write(name, png_fixture())
        self.manifest(name)
        with patch.object(release, "PNG_FILES", {name: (2, 2)}):
            self.assertEqual(release.check(), [])
            self.write(name, png_fixture(after=b"hidden"))
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

    def test_pages_marker_is_empty_and_cannot_hide_content(self):
        self.manifest("docs/.nojekyll")
        self.write("docs/.nojekyll", "")
        self.assertEqual(release.check(), [])
        self.write("docs/.nojekyll", "Unreviewed content")
        self.assertIn("The Pages configuration marker must be empty.", release.check())

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


class StaticSiteBoundaryTests(unittest.TestCase):
    allowed = release.SITE_FILES | release.SVG_FILES | release.PNG_FILES.keys() | {
        "docs/.nojekyll", "docs/METHODS.md", "docs/DATA_POLICY.md",
    }

    def test_site_assets_and_reviewed_figure_links_are_accepted(self):
        content = (
            '<!doctype html><html lang="en"><head><meta charset="utf-8">'
            '<link rel="stylesheet" href="styles.css">'
            '<script src="gallery.js" defer></script></head><body>'
            '<nav><a href="#tree">Tree</a><a href="METHODS.md">Methods</a></nav>'
            '<figure id="tree"><img src="figures/synthetic_tree.svg" '
            'alt="Entirely synthetic phylogenetic tree"></figure>'
            '<a href="' + release.REPOSITORY_URL + '">Repository</a>'
            '</body></html>'
        )
        self.assertEqual(release.check_html(content, self.allowed), [])
        self.assertEqual(release.check_html(
            '<img src="figures/method_tree.png" alt="Simulated trait mapping on a new tree">',
            self.allowed), [])

    def test_actual_site_assets_pass_their_boundaries(self):
        self.assertEqual(release.check_html(
            (release.ROOT / "docs/index.html").read_text(encoding="utf-8"), self.allowed), [])
        self.assertEqual(release.check_css(
            (release.ROOT / "docs/styles.css").read_text(encoding="utf-8")), [])
        self.assertEqual(release.check_javascript(
            (release.ROOT / "docs/gallery.js").read_text(encoding="utf-8")), [])

    def test_images_cannot_escape_docs_or_fetch_external_content(self):
        for path in (
            "../README.md", "/figures/synthetic_tree.svg", "figures/../synthetic_tree.svg",
            "%2e%2e/README.md", "figures%2fsynthetic_tree.svg", "//example.invalid/tree.svg",
            "https://example.invalid/tree.svg", "data:image/svg+xml,hidden",
            "figures/unreviewed.svg", "figures/synthetic_tree.svg?tracking=1",
            "figures/synthetic_tree.svg#hidden",
        ):
            with self.subTest(path=path):
                self.assertTrue(release.check_html(f'<img src="{path}" alt="Synthetic tree">', self.allowed))

    def test_no_inline_active_markup_or_embedded_documents(self):
        for content in (
            '<iframe src="figures/synthetic_tree.svg"></iframe>',
            '<object data="figures/synthetic_tree.svg"></object>',
            '<form action="https://example.invalid/"></form>',
            '<script>alert(1)</script>',
            '<script src="gallery.js">alert(1)</script>',
            '<script type="module" src="gallery.js"></script>',
            '<style>@import "https://example.invalid/theme.css";</style>',
            '<div style="background:red">Hidden style</div>',
            '<button onclick="alert(1)">Open</button>',
            '<meta http-equiv="refresh" content="0;url=https://example.invalid/">',
            '<img src="figures/synthetic_tree.svg">',
        ):
            with self.subTest(content=content):
                self.assertTrue(release.check_html(content, self.allowed))

    def test_links_are_local_or_belong_to_the_public_repository(self):
        for destination in (
            "https://github.com/another/repository", "https://example.invalid/",
            release.REPOSITORY_URL + ".invalid", release.REPOSITORY_URL + "/../private",
            release.REPOSITORY_URL + "/%2e%2e/private", "javascript:alert(1)", "../README.md",
        ):
            with self.subTest(destination=destination):
                self.assertTrue(release.check_html(f'<a href="{destination}">Link</a>', self.allowed))
        self.assertTrue(release.check_html('<a href="#missing">Missing section</a>', self.allowed))

    def test_stylesheet_accepts_layout_but_no_network_or_embedded_assets(self):
        self.assertEqual(release.check_css(
            ':root { --ink: #173b40; } @media (max-width: 50rem) { .grid { display: block; } }'), [])
        for content in (
            '@import "https://example.invalid/theme.css";',
            'body { background: url(https://example.invalid/pixel); }',
            'body { background: url(data:image/png;base64,AAAA); }',
            'body { background: image-set("https://example.invalid/image.png" 1x); }',
            'body { width: expression(alert(1)); }',
            'body { background: u' + chr(92) + '72l(hidden); }',
        ):
            with self.subTest(content=content):
                self.assertTrue(release.check_css(content))

    def test_gallery_script_is_dom_only_and_has_no_dynamic_loads(self):
        self.assertEqual(release.check_javascript(
            'document.querySelectorAll("button").forEach(button => {'
            'button.addEventListener("click", () => { button.hidden = false; }); });'), [])
        for content in (
            'fetch("/private")', 'new XMLHttpRequest()', 'new WebSocket("wss://example.invalid")',
            'import("./unreviewed.js")', 'eval("alert(1)")', 'new Function("return 1")',
            'localStorage.getItem("example")', 'document.cookie',
            'element.innerHTML = value', 'element.setAttribute("src", value)',
            'element.src = value', 'window.location = value',
        ):
            with self.subTest(content=content):
                self.assertTrue(release.check_javascript(content))

    def test_html_css_and_js_are_only_allowed_at_reviewed_paths(self):
        for name in ("other.html", "docs/extra.js", "docs/extra.css"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text("Unexpected content", encoding="utf-8")
                (root / "release-files.txt").write_text("release-files.txt\n" + name + "\n", encoding="utf-8")
                with patch.object(release, "ROOT", root):
                    self.assertIn("Invalid allowlist path or file type.", release.check())


if __name__ == "__main__":
    unittest.main()
