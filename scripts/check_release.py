#!/usr/bin/env python3
"""Check the explicit publication boundary; no private denylist is distributed."""

import argparse
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SPECIAL = {".gitattributes", ".gitignore", "release-files.txt", "docs/.nojekyll"}
SUFFIXES = {".R", ".md", ".py", ".yml"}
SVG_FILES = {
    "docs/figures/synthetic_tree.svg", "docs/figures/synthetic_workflow.svg",
    "docs/figures/synthetic_imputation.svg", "docs/figures/synthetic_pca.svg",
    "docs/figures/synthetic_correlation.svg",
}
SITE_FILES = {"docs/index.html", "docs/styles.css", "docs/gallery.js"}
REPOSITORY_URL = "https://github.com/SuperAmazingMatt/coral-trait-phylogenetics"
HTML_TAGS = {
    "html", "head", "body", "meta", "title", "link", "script", "header", "nav",
    "main", "section", "article", "div", "span", "p", "h1", "h2", "h3", "h4",
    "h5", "h6", "a", "button", "figure", "figcaption", "img", "ul", "ol", "li",
    "dl", "dt", "dd", "footer", "aside", "small", "strong", "em", "br", "hr", "code",
    "pre", "details", "summary", "table", "thead", "tbody", "tr", "th", "td",
    "b", "i", "sup", "sub",
}
HTML_ATTRIBUTES = {
    "id", "class", "lang", "dir", "role", "title", "hidden", "tabindex",
    "href", "src", "alt", "width", "height", "loading", "decoding", "type",
    "rel", "target", "download", "defer", "charset", "name", "content",
    "open", "colspan", "rowspan", "scope", "disabled", "fetchpriority",
}
SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
SVG_ELEMENTS = {
    "svg", "title", "desc", "defs", "g", "symbol", "path", "rect", "clipPath",
    "use", "line", "polyline", "polygon", "circle", "ellipse",
}
SVG_ATTRIBUTES = {
    "width", "height", "viewBox", "version", "id", "x", "y", "x1", "y1", "x2", "y2",
    "cx", "cy", "r", "rx", "ry", "d", "points", "transform", "style", "href",
    "preserveAspectRatio", "clipPathUnits", "role", "aria-labelledby", "aria-describedby",
}
SVG_STYLES = {
    "fill", "fill-rule", "fill-opacity", "stroke", "stroke-width", "stroke-linecap",
    "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset",
    "stroke-opacity", "opacity", "clip-path", "clip-rule", "overflow",
}
LOCAL_REF = re.compile(r"#[A-Za-z_][A-Za-z0-9_.:-]*\Z")
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


def check_svg(content):
    """Accept only static, self-contained synthetic figure markup.

    Provenance markers are required labels, not evidence that content is synthetic.
    The source generation and figure must still be reviewed before publication.
    """
    if re.search(r"<!DOCTYPE|<!ENTITY|<!--|<\?(?!xml\s)", content, re.I):
        return ["SVG contains a declaration, comment, or processing instruction."]
    try:
        root = ET.fromstring(content)
    except ET.ParseError:
        return ["SVG is not well-formed XML."]
    if root.tag != f"{{{SVG_NS}}}svg":
        return ["SVG root must use the SVG namespace."]
    for tag in ("title", "desc"):
        labels = root.findall(f"{{{SVG_NS}}}{tag}")
        if (len(labels) != 1 or len(labels[0]) or
                not re.search(r"\bsynthetic\b", labels[0].text or "", re.I)):
            return ["SVG requires one plain synthetic title and description."]

    references = []
    identifiers = set()
    for element in root.iter():
        prefix = f"{{{SVG_NS}}}"
        if not element.tag.startswith(prefix) or element.tag[len(prefix):] not in SVG_ELEMENTS:
            return ["SVG contains an unsupported or active element."]
        tag = element.tag[len(prefix):]
        if tag in {"title", "desc"} and element not in list(root):
            return ["SVG contains nested descriptive text."]
        if ((tag not in {"title", "desc"} and (element.text or "").strip()) or
                (element.tail or "").strip()):
            return ["SVG contains text outside its visible provenance labels."]
        for name, value in element.attrib.items():
            if name == f"{{{XLINK_NS}}}href":
                name = "href"
            if name not in SVG_ATTRIBUTES | SVG_STYLES:
                return ["SVG contains an unsupported attribute."]
            if name == "href":
                if tag != "use" or not LOCAL_REF.fullmatch(value):
                    return ["SVG contains an external or unsupported reference."]
                references.append(value[1:])
            elif name == "id":
                if not LOCAL_REF.fullmatch("#" + value) or value in identifiers:
                    return ["SVG contains an invalid or duplicate identifier."]
                identifiers.add(value)
            elif name in {"aria-labelledby", "aria-describedby"}:
                if not value.split():
                    return ["SVG has an empty accessibility reference."]
                references.extend(value.split())
            elif name == "role":
                if tag != "svg" or value != "img":
                    return ["SVG has an unsupported accessibility role."]
            elif name == "style":
                for declaration in value.split(";"):
                    if not declaration.strip():
                        continue
                    prop, separator, css_value = declaration.partition(":")
                    if not separator or not safe_svg_style(prop.strip(), css_value.strip(), references):
                        return ["SVG contains an unsupported or hidden style."]
            elif name in SVG_STYLES:
                if not safe_svg_style(name, value, references):
                    return ["SVG contains an unsupported or hidden style."]
            elif re.search(r"(?i)(?:url\s*\(|javascript:|data:|https?://)", value):
                return ["SVG contains an external or embedded resource."]
    if any(reference not in identifiers for reference in references):
        return ["SVG contains an unresolved local reference."]
    return []


def safe_svg_style(name, value, references):
    if name not in SVG_STYLES or re.search(r"[\\@]|/\*|expression\s*\(|(?:https?|data|javascript):", value, re.I):
        return False
    if name == "clip-rule" and value not in {"nonzero", "evenodd"}:
        return False
    if "url" in value.lower():
        match = re.fullmatch(r"url\(\s*['\"]?(#[A-Za-z_][A-Za-z0-9_.:-]*)['\"]?\s*\)", value)
        if name != "clip-path" or not match:
            return False
        references.append(match.group(1)[1:])
    if name in {"opacity", "fill-opacity", "stroke-opacity"}:
        try:
            if not 0 < float(value) <= 1:
                return False
        except ValueError:
            return False
    if name == "overflow" and value != "visible":
        return False
    return True


def local_site_path(value, allowed):
    """Resolve a site asset without allowing encoding tricks or directory escape."""
    decoded = unquote(value)
    parsed = urlsplit(decoded)
    path = PurePosixPath(parsed.path)
    if (decoded != value or parsed.scheme or parsed.netloc or parsed.query or
            not parsed.path or path.is_absolute() or ".." in path.parts or
            "\\" in value or any(ord(c) < 33 for c in value)):
        return None
    resolved = (PurePosixPath("docs") / path).as_posix()
    return resolved if resolved in allowed else None


class SiteMarkup(HTMLParser):
    """Inspect a deliberately small static site, not arbitrary web applications."""

    def __init__(self, allowed):
        HTMLParser.__init__(self, convert_charrefs=True)
        self.allowed = allowed
        self.errors = []
        self.identifiers = set()
        self.fragments = []
        self.in_script = False

    def reject(self, message):
        if message not in self.errors:
            self.errors.append(message)

    def handle_decl(self, decl):
        if decl.lower() != "doctype html":
            self.reject("HTML contains an unsupported declaration.")

    def handle_pi(self, data):
        self.reject("HTML contains a processing instruction.")

    def unknown_decl(self, data):
        self.reject("HTML contains an unsupported declaration.")

    def handle_starttag(self, tag, attrs):
        if tag not in HTML_TAGS:
            self.reject("HTML contains an unsupported or embedded element.")
        attributes = dict(attrs)
        if len(attributes) != len(attrs):
            self.reject("HTML contains duplicate attributes.")
        for name, value in attrs:
            if (name not in HTML_ATTRIBUTES and
                    not re.fullmatch(r"(?:aria|data)-[a-z][a-z0-9-]*", name)):
                self.reject("HTML contains an unsupported or active attribute.")
            if value and re.search(r"(?i)(?:javascript|data|vbscript):", value):
                self.reject("HTML contains an executable or embedded URL.")
            if name == "id":
                if not value or value in self.identifiers:
                    self.reject("HTML contains an invalid or duplicate identifier.")
                self.identifiers.add(value)
            if name in {"href", "src"}:
                self.check_reference(tag, name, value or "")
        if tag == "link" and attributes.get("rel") != "stylesheet":
            self.reject("HTML may link only its reviewed stylesheet.")
        if tag == "script":
            self.in_script = True
            if (attributes.get("src") != "gallery.js" or
                    attributes.get("type", "text/javascript") != "text/javascript"):
                self.reject("HTML may load only its reviewed local gallery script.")
        if tag == "img" and not attributes.get("alt"):
            self.reject("HTML figures require descriptive alternate text.")
        if tag == "a" and attributes.get("target") == "_blank":
            if "noopener" not in attributes.get("rel", "").split():
                self.reject("HTML external tabs require noopener.")

    def check_reference(self, tag, attribute, value):
        if tag == "a" and attribute == "href":
            if value.startswith("#"):
                if len(value) == 1:
                    self.reject("HTML contains an empty fragment link.")
                else:
                    self.fragments.append(value[1:])
                return
            url = urlsplit(value)
            if value == REPOSITORY_URL or value.startswith(REPOSITORY_URL + "/") or value.startswith(REPOSITORY_URL + "#"):
                if (url.username or url.password or url.query or unquote(value) != value or
                        ".." in PurePosixPath(url.path).parts or "\\" in value or
                        any(ord(c) < 33 for c in value)):
                    self.reject("HTML contains an unsupported repository link.")
                return
            if local_site_path(value, self.allowed):
                return
        elif (tag, attribute) in {("img", "src"), ("link", "href"), ("script", "src")}:
            resolved = local_site_path(value, self.allowed)
            permitted = SVG_FILES if tag == "img" else {
                "docs/styles.css" if tag == "link" else "docs/gallery.js"
            }
            if resolved in permitted and not urlsplit(value).fragment:
                return
        self.reject("HTML contains an unreviewed, external, or escaping resource reference.")

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_script = False

    def handle_data(self, data):
        if self.in_script and data.strip():
            self.reject("HTML contains inline script content.")


def check_html(content, allowed):
    markup = SiteMarkup(allowed)
    try:
        markup.feed(content)
        markup.close()
    except (ValueError, AssertionError):
        return ["HTML could not be parsed."]
    if any(fragment not in markup.identifiers for fragment in markup.fragments):
        markup.reject("HTML contains an unresolved navigation fragment.")
    return markup.errors


def check_css(content):
    # No imported fonts, embedded assets, or remote resources are needed here.
    if re.search(r"\\|@import\b|url\s*\(|image-set\s*\(|expression\s*\(|"
                 r"(?:https?|data|javascript):|(?<![\w-])(?:behavior|-moz-binding)\s*:", content, re.I):
        return ["CSS contains an imported, embedded, or executable resource."]
    return []


def check_javascript(content):
    # This conservative screen complements review of the small DOM-only script;
    # it is not a sandbox for arbitrary or deliberately obfuscated JavaScript.
    forbidden = (
        r"\b(?:fetch|XMLHttpRequest|WebSocket|EventSource|Worker|SharedWorker|"
        r"WebAssembly|import|eval|constructor|Reflect|atob|btoa|"
        r"localStorage|sessionStorage|indexedDB|sendBeacon|serviceWorker|"
        r"innerHTML|outerHTML|insertAdjacentHTML|cookie|location)\b|"
        r"document\s*\.\s*write\b|(?:https?|data|javascript):|"
        r"\.\s*(?:src|href)\s*=|setAttribute\s*\(\s*['\"](?:src|href)['\"]"
    )
    if re.search(forbidden, content, re.I) or re.search(r"\bFunction\b", content):
        return ["JavaScript contains networking, storage, dynamic code, or unreviewed content insertion."]
    return []


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
                (name not in SPECIAL and name not in SVG_FILES and
                 name not in SITE_FILES and path.suffix not in SUFFIXES)):
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
        if name in SVG_FILES:
            problems.extend(f"{problem} File: {name}" for problem in check_svg(content))
        if name == "docs/index.html":
            problems.extend(f"{problem} File: {name}" for problem in check_html(content, allowed))
        if name == "docs/styles.css":
            problems.extend(f"{problem} File: {name}" for problem in check_css(content))
        if name == "docs/gallery.js":
            problems.extend(f"{problem} File: {name}" for problem in check_javascript(content))
        if name == "docs/.nojekyll" and content:
            problems.append("The Pages configuration marker must be empty.")
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
