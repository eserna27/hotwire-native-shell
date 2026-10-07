#!/usr/bin/env python3
"""The itsjustmy brand file reproduces the Portada set the renderer understands."""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"test_store_brand: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    raw = subprocess.check_output(
        [sys.executable, str(ROOT / "tools" / "store-screenshots" / "load_brand.py"), str(ROOT / "store" / "brand.yml")],
        text=True,
    )
    brand = json.loads(raw)
    if brand["display_name"] != "itsjustmy.blog":
        fail("display_name")
    if brand["colors"]["mint"] != "#6EE7B7" or brand["colors"]["ink"] != "#0F172A":
        fail("colors")
    if brand["fonts"]["display"] != "Bodoni Moda":
        fail("fonts")
    es = [slide["id"] for slide in brand["locales"]["es"]["slides"]]
    en = [slide["id"] for slide in brand["locales"]["en"]["slides"]]
    if es != en or es != ["01-blog", "02-editor", "03-post", "04-dashboard", "05-categories", "06-username"]:
        fail(f"slides {es} {en}")
    editor = brand["locales"]["es"]["slides"][1]
    if editor["screen"]["srcs"] != ["app_editor.png"] or editor["screen"]["ipad"] != ["ipad_editor.png"]:
        fail("editor drop-ins")
    names = {item["file"] for item in brand["drop_ins"]}
    for required in ("app_editor.png", "ipad_editor.png", "app_dashboard.png", "ipad_dashboard.png"):
        if required not in names:
            fail(f"missing drop-in {required}")
    if "Tu blog,<br><em>en tu bolsillo.</em>" not in brand["locales"]["es"]["slides"][0]["headline"]:
        fail("spanish headline")
    if "in your pocket" not in brand["locales"]["en"]["feature"]["headline"]:
        fail("english feature")
    template = (ROOT / "tools" / "store-screenshots" / "template" / "index.html").read_text()
    for token in ("1320", "2868", "2064", "2752", "1080", "1920", "brand.runtime.js"):
        if token not in template:
            fail(f"template missing {token}")
    feature = (ROOT / "tools" / "store-screenshots" / "template" / "feature.html").read_text()
    if "1024" not in feature or "itsjustmy.blog" in feature:
        fail("feature graphic should be generic")
    formats = (ROOT / "tools" / "store-screenshots" / "formats.js").read_text()
    for token in ("1320", "2868", "2064", "2752", "1080", "1920", "1024", "500"):
        if token not in formats:
            fail(f"formats missing {token}")
    print("test_store_brand ok")


if __name__ == "__main__":
    main()
