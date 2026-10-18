#!/usr/bin/env python3
"""Check imported source bytes and local links in maintained Markdown.

This deliberately small checker handles single-line inline links/images, including
angle-bracket destinations, optional titles and balanced/escaped parentheses.
Fenced code blocks and inline code spans are ignored. Reference-style links, HTML
links and heading fragments are outside its scope; fragments only have their file
path checked. No network requests are made.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
from urllib.parse import unquote


LINK_START = re.compile(r"!?\[(?:\\.|[^\]\\\n])*\]\(")
URI_SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
FENCE_START = re.compile(r"^ {0,3}(`{3,}|~{3,})")
PUNCTUATION_ESCAPE = re.compile(r"\\([!\"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])")


def display(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


def within_root(path: Path, root: Path) -> bool:
    return path.is_relative_to(root)


def check_imports(root: Path, errors: list[str]) -> tuple[set[Path], int, int]:
    manifest_path = root / "docs/IMPORT_MANIFEST.json"
    label = display(manifest_path, root)
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        errors.append(f"{label}: cannot read manifest: {exc}")
        return set(), 0, 0
    entries = manifest.get("files") if isinstance(manifest, dict) else None
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}: 'files' must be a nonempty list")
        return set(), 0, 0

    imported: set[Path] = set()
    verified = 0
    for index, entry in enumerate(entries, 1):
        location = f"{label}: files[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{location}: entry must be an object")
            continue
        raw_path = entry.get("path")
        if not isinstance(raw_path, str) or not raw_path or "\\" in raw_path:
            errors.append(f"{location}: path must be a relative POSIX path")
            continue
        relative = PurePosixPath(raw_path)
        if relative.is_absolute() or ".." in relative.parts or URI_SCHEME.match(raw_path):
            errors.append(f"{location}: path escapes repository: {raw_path}")
            continue
        path = (root / relative).resolve()
        if not within_root(path, root):
            errors.append(f"{location}: path escapes repository: {raw_path}")
            continue
        if path in imported:
            errors.append(f"{location}: duplicate imported path: {raw_path}")
            continue
        imported.add(path)

        size = entry.get("size_bytes")
        sha256 = entry.get("sha256")
        if type(size) is not int or size < 0 or not isinstance(sha256, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", sha256):
            errors.append(f"{location}: invalid size_bytes or SHA-256")
            continue
        try:
            content = path.read_bytes()
        except OSError as exc:
            errors.append(f"{raw_path}: cannot read imported file: {exc.strerror}")
            continue
        if len(content) != size or hashlib.sha256(content).hexdigest() != sha256.lower():
            errors.append(f"{raw_path}: imported bytes differ from manifest (size/SHA-256)")
            continue
        verified += 1
    return imported, verified, len(entries)


def without_inline_code(line: str) -> str:
    """Mask paired backtick spans without changing link positions."""
    spans = list(re.finditer(r"`+", line))
    masked = list(line)
    index = 0
    while index < len(spans):
        opening = spans[index]
        closing_index = next(
            (n for n in range(index + 1, len(spans)) if spans[n].group() == opening.group()),
            None,
        )
        if closing_index is None:
            index += 1
            continue
        closing = spans[closing_index]
        masked[opening.start():closing.end()] = " " * (closing.end() - opening.start())
        index = closing_index + 1
    return "".join(masked)


def destination(line: str, start: int) -> str | None:
    """Read the destination after ']('; an optional title is not part of it."""
    index = start
    while index < len(line) and line[index].isspace():
        index += 1
    angle = index < len(line) and line[index] == "<"
    if angle:
        index += 1
    begin = index
    depth = 0
    while index < len(line):
        char = line[index]
        if char == "\\":
            index += 2
            continue
        if angle:
            if char == ">":
                return line[begin:index]
        elif char == "(":
            depth += 1
        elif char == ")":
            if depth == 0:
                return line[begin:index]
            depth -= 1
        elif char.isspace() and depth == 0:
            return line[begin:index]
        index += 1
    return None


def check_links(root: Path, imported: set[Path], errors: list[str]) -> tuple[int, int]:
    documents = sorted((root / "docs").rglob("*.md"))
    documents += [root / name for name in ("README.md", "AGENTS.md") if (root / name).is_file()]
    maintained = [path for path in documents if path.resolve() not in imported]
    checked = 0
    for path in maintained:
        label = display(path, root)
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError) as exc:
            errors.append(f"{label}: cannot read Markdown: {exc}")
            continue
        fence: str | None = None
        for line_number, line in enumerate(lines, 1):
            if fence is not None:
                if re.fullmatch(r" {0,3}" + re.escape(fence[0]) + "{" + str(len(fence)) + r",}\s*", line):
                    fence = None
                continue
            opening = FENCE_START.match(line)
            if opening:
                fence = opening.group(1)
                continue
            visible = without_inline_code(line)
            for match in LINK_START.finditer(visible):
                target = destination(line, match.end())
                if target is None:
                    continue
                target = PUNCTUATION_ESCAPE.sub(r"\1", target)
                if not target or target.startswith(("#", "/")) or URI_SCHEME.match(target):
                    continue
                local_path = unquote(target.split("#", 1)[0].split("?", 1)[0])
                if not local_path:
                    continue
                checked += 1
                try:
                    resolved = (path.parent / local_path).resolve()
                    if not within_root(resolved, root):
                        errors.append(f"{label}:{line_number}: link escapes repository: {target}")
                    elif not resolved.exists():
                        errors.append(f"{label}:{line_number}: missing link target: {target}")
                except (OSError, ValueError) as exc:
                    errors.append(f"{label}:{line_number}: invalid link target {target!r}: {exc}")
    return len(maintained), checked


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1], help="repository root (default: parent of scripts/)")
    args = parser.parse_args()
    root = args.root.resolve()
    errors: list[str] = []
    imported, verified, total = check_imports(root, errors)
    documents, links = check_links(root, imported, errors)
    for error in errors:
        print(f"ERROR {error}")
    print(f"Docs: {verified}/{total} imported files unchanged; {documents} maintained Markdown files; {links} local links checked; {len(errors)} errors.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
