#!/usr/bin/env python3
"""Create a client flavor from an interactive questionnaire or an app.yml file.

Writes flavors/<slug>, the Android product flavor, the single iOS target
(bundle id, display name, bundled native folder, splash, and push entitlement
when push is on), and store/brand.yml for the screenshot toolkit.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import xml.sax.saxutils
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    print("new-app: install PyYAML (the python3-yaml package)", file=sys.stderr)
    sys.exit(1)

BRIDGE_KEYS = (
    "notification_token",
    "share",
    "haptic",
    "camera",
    "biometric",
    "clipboard",
    "file_download",
)
TAB_ICONS = ("home", "posts", "search", "profile", "info")
SLUG_RE = re.compile(r"^[a-z][a-z0-9]*$")
APP_ID_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$")
TAB_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")
TOPIC_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")
RESOURCE_RE = re.compile(r"^[a-z][a-z0-9_]*$")
IOS_TARGET = "A10000000000000000000010"
ENTITLEMENTS_REL = "HotwireNativeShell/HotwireNativeShell.entitlements"


class AppError(Exception):
    pass


def fail(message: str) -> None:
    raise AppError(message)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def load_yaml(path: Path) -> dict:
    try:
        document = yaml.safe_load(path.read_text())
    except yaml.YAMLError as exc:
        fail(f"{path}: {exc}")
    if not isinstance(document, dict):
        fail(f"{path} must be a mapping")
    return document


def suggest_slug(display_name: str) -> str:
    base = display_name.strip().lower()
    for suffix in (".blog", ".com", ".app", ".dev", ".io", ".org", ".net"):
        if base.endswith(suffix):
            base = base[: -len(suffix)]
            break
    return re.sub(r"[^a-z0-9]", "", base) or "app"


def hex_color(value: object, label: str) -> str:
    if not isinstance(value, str) or not COLOR_RE.match(value.strip()):
        fail(f"{label} must be a #RRGGBB color")
    return value.strip().upper()


def hex_rgb(value: str) -> tuple[int, int, int]:
    raw = value.lstrip("#")
    return int(raw[0:2], 16), int(raw[2:4], 16), int(raw[4:6], 16)


def origin(value: object, label: str, *, https: bool) -> str:
    if not isinstance(value, str) or not value.strip():
        fail(f"missing {label}")
    text = value.strip().rstrip("/")
    parsed = urllib.parse.urlparse(text)
    if parsed.scheme not in ("https", "http") or not parsed.netloc:
        fail(f"{label} must be an absolute origin")
    if parsed.path not in ("", "/") or parsed.params or parsed.query or parsed.fragment:
        fail(f"{label} must be an origin with no path, query, or fragment")
    host = (parsed.hostname or "").lower()
    local = host in ("localhost", "127.0.0.1", "10.0.2.2")
    if https and parsed.scheme != "https" and not local:
        fail(f"{label} must be https")
    return f"{parsed.scheme}://{parsed.netloc}"


def android_emulator_origin(dev_base_url: str) -> str:
    parsed = urllib.parse.urlparse(dev_base_url)
    host = (parsed.hostname or "").lower()
    if host not in ("localhost", "127.0.0.1"):
        return dev_base_url
    port = f":{parsed.port}" if parsed.port else ""
    return f"{parsed.scheme}://10.0.2.2{port}"


def normalize_path(value: object, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        fail(f"missing {label}")
    path = value.strip()
    if "://" in path or any(char.isspace() for char in path):
        fail(f"{label} must be a path with no scheme or whitespace")
    if not path.startswith("/"):
        path = "/" + path
    return path


def normalize_tab(item: object, index: int) -> dict:
    if not isinstance(item, dict):
        fail(f"tabs[{index}] must be a mapping")
    tab_id = item.get("id")
    if not isinstance(tab_id, str) or not TAB_ID_RE.match(tab_id):
        fail(f"tabs[{index}].id must be 1–64 characters (letters, digits, . _ -)")
    title = item.get("title")
    titles = item.get("titles") if isinstance(item.get("titles"), dict) else None
    if titles is not None:
        cleaned_titles = {}
        for key, value in titles.items():
            if not isinstance(key, str) or not isinstance(value, str) or not value.strip():
                fail(f"tabs[{index}].titles values must be strings")
            cleaned_titles[key] = value.strip()
        titles = cleaned_titles or None
    if not isinstance(title, str) or not title.strip():
        if titles:
            title = titles.get("es") or titles.get("en") or next(iter(titles.values()))
        else:
            fail(f"tabs[{index}] needs a title")
    title = str(title).strip()
    if "path" in item and item.get("path") not in (None, ""):
        location: dict[str, str] = {"path": normalize_path(item.get("path"), f"tabs[{index}].path")}
    elif isinstance(item.get("url"), str) and item["url"].strip():
        url = item["url"].strip()
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            fail(f"tabs[{index}].url must be an absolute http(s) URL")
        location = {"url": url}
    else:
        fail(f"tabs[{index}] needs a path or a url")
    icon = item.get("icon") or "home"
    if icon not in TAB_ICONS:
        fail(f"tabs[{index}].icon must be one of {', '.join(TAB_ICONS)}")
    tab = {"id": tab_id, "title": title}
    if titles:
        tab["titles"] = titles
    tab.update(location)
    tab["icon"] = icon
    if item.get("sf_symbol"):
        symbol = str(item["sf_symbol"]).strip()
        if not symbol or any(char.isspace() for char in symbol):
            fail(f"tabs[{index}].sf_symbol must be an SF Symbol name")
        tab["sf_symbol"] = symbol
    if item.get("android_icon"):
        drawable = str(item["android_icon"]).strip()
        if not RESOURCE_RE.match(drawable):
            fail(f"tabs[{index}].android_icon must be an Android drawable name")
        tab["android_icon"] = drawable
    return tab


def normalize_bridges(value: object) -> dict[str, bool]:
    raw = value if isinstance(value, dict) else {}
    unknown = sorted(set(raw) - set(BRIDGE_KEYS))
    if unknown:
        fail(f"unknown bridge keys: {', '.join(unknown)}")
    bridges = {}
    for key in BRIDGE_KEYS:
        if key not in raw:
            bridges[key] = False
            continue
        if not isinstance(raw[key], bool):
            fail(f"bridges.{key} must be true or false")
        bridges[key] = raw[key]
    return bridges


def normalize(document: dict) -> dict:
    display_name = document.get("display_name")
    if not isinstance(display_name, str) or not display_name.strip():
        fail("missing display_name")
    display_name = display_name.strip()
    slug = document.get("slug") or suggest_slug(display_name)
    if not isinstance(slug, str) or not SLUG_RE.match(slug):
        fail("slug must be a lower-case Gradle flavor name (letters and digits, starting with a letter)")
    application_id = document.get("application_id") or document.get("bundle_id")
    if not isinstance(application_id, str) or not APP_ID_RE.match(application_id.strip()):
        fail("application_id must be a reverse-DNS bundle id")
    application_id = application_id.strip()
    base_url = origin(document.get("base_url"), "base_url", https=True)
    dev_base_url = origin(document.get("dev_base_url"), "dev_base_url", https=False)
    if document.get("android_dev_base_url"):
        android_dev = origin(document.get("android_dev_base_url"), "android_dev_base_url", https=False)
    else:
        android_dev = android_emulator_origin(dev_base_url)
    colors_in = document.get("colors") if isinstance(document.get("colors"), dict) else {}
    colors = {
        "primary": hex_color(colors_in.get("primary") or "#6EE7B7", "colors.primary"),
        "secondary": hex_color(colors_in.get("secondary") or "#3B82F6", "colors.secondary"),
        "ink": hex_color(colors_in.get("ink") or "#0F172A", "colors.ink"),
        "paper": hex_color(colors_in.get("paper") or "#F6F2E8", "colors.paper"),
        "splash_background": hex_color(
            colors_in.get("splash_background") or document.get("splash_background") or "#FFFFFF",
            "colors.splash_background",
        ),
    }
    icon = document.get("icon")
    if icon is not None and not isinstance(icon, str):
        fail("icon must be a file path or a URL")
    start_path = normalize_path(document.get("start_path") or "/", "start_path")
    extra_paths = document.get("start_paths")
    paths = [start_path]
    if isinstance(extra_paths, list):
        paths = [normalize_path(item, "start_paths") for item in extra_paths]
        start_path = paths[0]
    tabs_in = document.get("tabs")
    if tabs_in is None:
        tabs = []
        if len(paths) >= 2:
            tabs = []
            for path in paths:
                leaf = path.strip("/").split("/")[-1] or "home"
                tab_id = re.sub(r"[^A-Za-z0-9._-]", "", leaf) or "home"
                if not TAB_ID_RE.match(tab_id):
                    tab_id = "home"
                tabs.append({"id": tab_id, "title": leaf.replace("-", " ").title(), "path": path, "icon": "home"})
    elif isinstance(tabs_in, list):
        if len(tabs_in) > 5:
            fail("at most five cold-start tabs")
        tabs = [normalize_tab(item, index) for index, item in enumerate(tabs_in)]
        seen = set()
        for tab in tabs:
            if tab["id"] in seen:
                fail(f"duplicate tab id {tab['id']}")
            seen.add(tab["id"])
    else:
        fail("tabs must be a list")
    push_in = document.get("push") if isinstance(document.get("push"), dict) else {}
    enabled = push_in.get("enabled", False)
    if not isinstance(enabled, bool):
        fail("push.enabled must be true or false")
    topics_in = push_in.get("topics") or []
    if not isinstance(topics_in, list) or not all(isinstance(item, str) and TOPIC_RE.match(item) for item in topics_in):
        fail("push.topics must be a list of topic names")
    google_services = push_in.get("google_services_json") or ""
    if google_services and not isinstance(google_services, str):
        fail("push.google_services_json must be a path")
    return {
        "display_name": display_name,
        "slug": slug,
        "application_id": application_id,
        "base_url": base_url,
        "dev_base_url": dev_base_url,
        "android_dev_base_url": android_dev,
        "colors": colors,
        "icon": icon.strip() if isinstance(icon, str) else "",
        "start_path": start_path,
        "tabs": tabs,
        "bridges": normalize_bridges(document.get("bridges")),
        "push": {
            "enabled": enabled,
            "topics": list(topics_in),
            "google_services_json": google_services.strip(),
        },
    }


def config_document(spec: dict) -> dict:
    document = {
        "name": spec["slug"],
        "base_url": spec["base_url"],
        "start_path": spec["start_path"],
        "bridges": spec["bridges"],
        "push": {"enabled": spec["push"]["enabled"], "topics": spec["push"]["topics"]},
    }
    if spec["tabs"]:
        document = {
            "name": spec["slug"],
            "base_url": spec["base_url"],
            "start_path": spec["start_path"],
            "tabs": spec["tabs"],
            "bridges": spec["bridges"],
            "push": {"enabled": spec["push"]["enabled"], "topics": spec["push"]["topics"]},
        }
    return document


def config_json(spec: dict) -> str:
    return json.dumps(config_document(spec), indent=2, ensure_ascii=False) + "\n"


def ask(label: str, default: str | None = None) -> str:
    suffix = f" [{default}]" if default else ""
    raw = input(f"{label}{suffix}: ").strip()
    if raw:
        return raw
    return default or ""


def ask_bool(label: str, default: bool = False) -> bool:
    hint = "Y/n" if default else "y/N"
    raw = input(f"{label} [{hint}]: ").strip().lower()
    if not raw:
        return default
    return raw in {"y", "yes", "true", "1"}


def prompt_spec() -> dict:
    print("New Hotwire Native client. Press enter to accept a default.\n")
    display_name = ""
    while not display_name:
        display_name = ask("Display name (home screen)")
    slug = ask("Slug (Gradle flavor)", suggest_slug(display_name))
    application_id = ask("Bundle id / applicationId", f"app.{slug}")
    base_url = ask("Production base URL (https origin)")
    dev_base_url = ask("Dev base URL (iOS simulator)", "http://localhost:9292")
    android_default = android_emulator_origin(dev_base_url) if dev_base_url else "http://10.0.2.2:9292"
    android_dev = ask("Dev base URL (Android emulator)", android_default)
    print("\nBrand colors as #RRGGBB.")
    colors = {
        "primary": ask("Primary", "#6EE7B7"),
        "secondary": ask("Secondary", "#3B82F6"),
        "ink": ask("Ink", "#0F172A"),
        "paper": ask("Paper", "#F6F2E8"),
        "splash_background": ask("Splash background", "#FFFFFF"),
    }
    icon = ""
    while not icon:
        icon = ask("Icon source (image file, SVG, or favicon URL)")
    start_raw = ask("Start path", "/")
    start_paths = [part.strip() for part in start_raw.split(",") if part.strip()]
    tabs = []
    print("\nCold-start tabs. Blank id ends the list. Two or more show the native bar. Cap is five.")
    while len(tabs) < 5:
        tab_id = ask("Tab id")
        if not tab_id:
            break
        title = ask("  Title")
        title_es = ask("  Spanish title (blank to skip)")
        title_en = ask("  English title (blank to skip)")
        path = ask("  Path", "/")
        icon_name = ask("  Icon (home, posts, search, profile, info)", "home")
        sf_symbol = ask("  SF Symbol override (blank to skip)")
        android_icon = ask("  Android drawable override (blank to skip)")
        tab = {"id": tab_id, "title": title or tab_id, "path": path, "icon": icon_name}
        titles = {}
        if title_es:
            titles["es"] = title_es
        if title_en:
            titles["en"] = title_en
        if titles:
            tab["titles"] = titles
        if sf_symbol:
            tab["sf_symbol"] = sf_symbol
        if android_icon:
            tab["android_icon"] = android_icon
        tabs.append(tab)
    print("\nBridges. menu, overflow-menu, and tabs are always registered.")
    bridges = {key: ask_bool(f"Enable {key}?", default=False) for key in BRIDGE_KEYS}
    push_enabled = ask_bool("\nEnable push?", default=False)
    topics: list[str] = []
    google_services = ""
    if push_enabled:
        raw_topics = ask("Push topics (comma-separated)", "posts")
        topics = [part.strip() for part in raw_topics.split(",") if part.strip()]
        google_services = ask("Path to google-services.json")
    document = {
        "display_name": display_name,
        "slug": slug,
        "application_id": application_id,
        "base_url": base_url,
        "dev_base_url": dev_base_url,
        "android_dev_base_url": android_dev,
        "colors": colors,
        "icon": icon,
        "start_path": start_paths[0] if start_paths else "/",
        "tabs": tabs,
        "bridges": bridges,
        "push": {"enabled": push_enabled, "topics": topics, "google_services_json": google_services},
    }
    if len(start_paths) > 1 and not tabs:
        document["start_paths"] = start_paths
    return normalize(document)


def resolve_existing(value: str, root: Path) -> Path | None:
    candidate = Path(value)
    if candidate.is_file():
        return candidate.resolve()
    rooted = (root / value).resolve()
    if rooted.is_file():
        return rooted
    return None


def http_get(url: str) -> tuple[bytes, str, str]:
    request = urllib.request.Request(url, headers={"User-Agent": "hotwire-native-shell-new-app"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read(), response.headers.get("Content-Type", ""), response.geturl()
    except Exception as exc:
        fail(f"could not fetch {url}: {exc}")
        raise


def looks_like_html(data: bytes, content_type: str) -> bool:
    if "html" in content_type.lower():
        return True
    sample = data[:200].lstrip().lower()
    return sample.startswith(b"<!doctype html") or sample.startswith(b"<html") or sample.startswith(b"<head")


def find_favicon(html: str, base: str) -> str:
    tags = re.findall(r"<link\b[^>]*>", html, flags=re.IGNORECASE)
    found: list[tuple[int, str]] = []
    for tag in tags:
        rel_match = re.search(r"rel\s*=\s*['\"]([^'\"]+)['\"]", tag, flags=re.IGNORECASE)
        href_match = re.search(r"href\s*=\s*['\"]([^'\"]+)['\"]", tag, flags=re.IGNORECASE)
        if not rel_match or not href_match:
            continue
        rels = set(rel_match.group(1).lower().split())
        if "icon" not in rels and "apple-touch-icon" not in rels and "shortcut" not in rels:
            continue
        score = 0
        if "apple-touch-icon" in rels:
            score += 2
        href = href_match.group(1)
        if href.lower().endswith(".svg"):
            score += 3
        elif href.lower().endswith(".png"):
            score += 1
        found.append((score, urllib.parse.urljoin(base, href)))
    if not found:
        return urllib.parse.urljoin(base, "/favicon.ico")
    found.sort(key=lambda item: item[0], reverse=True)
    return found[0][1]


def sniff_extension(data: bytes, url: str) -> str:
    if data.startswith(b"\x89PNG"):
        return ".png"
    if data.startswith(b"\xff\xd8"):
        return ".jpg"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    if data[:4] == b"\x00\x00\x01\x00":
        return ".ico"
    head = data[:300].lstrip().lower()
    if head.startswith(b"<svg") or head.startswith(b"<?xml") or b"<svg" in head:
        return ".svg"
    path = urllib.parse.urlparse(url).path.lower()
    for extension in (".svg", ".png", ".jpg", ".jpeg", ".webp", ".ico"):
        if path.endswith(extension):
            return ".jpg" if extension == ".jpeg" else extension
    fail("icon is not an SVG, PNG, JPEG, WEBP, or ICO")
    return ""


def materialize_icon(source: str, root: Path, work: Path) -> Path:
    if source.startswith("http://") or source.startswith("https://"):
        data, content_type, final = http_get(source)
        if looks_like_html(data, content_type):
            icon_url = find_favicon(data.decode("utf-8", "replace"), final)
            data, content_type, final = http_get(icon_url)
            if looks_like_html(data, content_type):
                fail(f"favicon URL returned HTML: {icon_url}")
        extension = sniff_extension(data, final)
        dest = work / f"icon-source{extension}"
        dest.write_bytes(data)
        return dest
    found = resolve_existing(source, root)
    if found is None:
        fail(f"icon not found: {source}")
    return found


def rasterize(src: Path, dest: Path, size: int, background: str | None = None) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.suffix.lower() == ".svg":
        png = dest if background is None else dest.with_name(dest.stem + "-raw.png")
        try:
            subprocess.run(
                ["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(png), str(src)],
                check=True,
            )
        except FileNotFoundError:
            fail("SVG icons need rsvg-convert (the librsvg2-bin package)")
        except subprocess.CalledProcessError as exc:
            fail(f"rsvg-convert failed ({exc.returncode}) for {src}")
        if background is None:
            return
        flatten_png(png, dest, size, background)
        png.unlink(missing_ok=True)
        return
    from PIL import Image

    image = Image.open(src).convert("RGBA")
    image = image.resize((size, size), Image.Resampling.LANCZOS)
    if background is None:
        image.save(dest)
        return
    flatten_png_image(image, dest, background)


def flatten_png(src: Path, dest: Path, size: int, background: str) -> None:
    from PIL import Image

    image = Image.open(src).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    flatten_png_image(image, dest, background)


def flatten_png_image(image, dest: Path, background: str) -> None:
    from PIL import Image

    canvas = Image.new("RGB", image.size, hex_rgb(background))
    canvas.paste(image, mask=image.split()[-1])
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest)


def xml_escape(value: str) -> str:
    return xml.sax.saxutils.escape(value)


def pbx_quote(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_.]+", value):
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def insert_before_block_end(text: str, open_token: str, insertion: str) -> str:
    start = text.find(open_token)
    if start < 0:
        fail(f"could not find {open_token.strip()} in the Android Gradle file")
    index = start + len(open_token)
    depth = 1
    while index < len(text) and depth:
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[:index] + insertion + text[index:]
        index += 1
    fail(f"unbalanced braces after {open_token.strip()}")
    return text


def upsert_marked_block(text: str, begin: str, end: str, block: str, open_token: str) -> str:
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
    if pattern.search(text):
        return pattern.sub(block, text, count=1)
    return insert_before_block_end(text, open_token, block)


def write_gradle(root: Path, spec: dict) -> None:
    path = root / "android" / "app" / "build.gradle.kts"
    text = path.read_text()
    slug = spec["slug"]
    flavor = (
        f"        // begin flavor {slug}\n"
        f"        create(\"{slug}\") {{\n"
        f"            dimension = \"client\"\n"
        f"            applicationId = \"{spec['application_id']}\"\n"
        f"        }}\n"
        f"        // end flavor {slug}\n"
    )
    assets = (
        f"        // begin flavor assets {slug}\n"
        f"        getByName(\"{slug}\") {{\n"
        f"            assets.srcDir(rootProject.file(\"../flavors/{slug}/assets\"))\n"
        f"        }}\n"
        f"        // end flavor assets {slug}\n"
    )
    text = upsert_marked_block(text, f"        // begin flavor {slug}\n", f"        // end flavor {slug}\n", flavor, "productFlavors {")
    text = upsert_marked_block(
        text,
        f"        // begin flavor assets {slug}\n",
        f"        // end flavor assets {slug}\n",
        assets,
        "sourceSets {",
    )
    path.write_text(text)


def colorset_json(color: str) -> str:
    red, green, blue = hex_rgb(color)
    return json.dumps(
        {
            "colors": [
                {
                    "color": {
                        "color-space": "srgb",
                        "components": {
                            "alpha": "1.000",
                            "blue": str(blue),
                            "green": str(green),
                            "red": str(red),
                        },
                    },
                    "idiom": "universal",
                }
            ],
            "info": {"author": "xcode", "version": 1},
        },
        indent=2,
    ) + "\n"


def write_android_resources(root: Path, spec: dict, artwork: Path) -> None:
    res = root / "android" / "app" / "src" / spec["slug"] / "res"
    values = res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "strings.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<resources>\n"
        f"    <string name=\"app_name\">{xml_escape(spec['display_name'])}</string>\n"
        "</resources>\n"
    )
    colors = spec["colors"]
    (values / "colors.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<resources>\n"
        f"    <color name=\"ic_launcher_background\">{colors['primary']}</color>\n"
        f"    <color name=\"splash_background\">{colors['splash_background']}</color>\n"
        "</resources>\n"
    )
    drawable = res / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    rasterize(artwork, drawable / "ic_launcher_artwork.png", 1024)
    (drawable / "ic_splash.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<layer-list xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
        "    <item android:drawable=\"@color/splash_background\" />\n"
        "    <item\n"
        "        android:width=\"144dp\"\n"
        "        android:height=\"144dp\"\n"
        "        android:gravity=\"center\"\n"
        "        android:drawable=\"@drawable/ic_launcher_artwork\" />\n"
        "</layer-list>\n"
    )
    adaptive = (
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<adaptive-icon xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
        "    <background android:drawable=\"@color/ic_launcher_background\" />\n"
        "    <foreground android:drawable=\"@drawable/ic_launcher_artwork\" />\n"
        "</adaptive-icon>\n"
    )
    mipmap = res / "mipmap-anydpi-v26"
    mipmap.mkdir(parents=True, exist_ok=True)
    (mipmap / "ic_launcher.xml").write_text(adaptive)
    (mipmap / "ic_launcher_round.xml").write_text(adaptive)


def set_pbx_setting(text: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^(\t*{re.escape(key)} = ).*;$", re.MULTILINE)

    def replace(match: re.Match[str]) -> str:
        return f"{match.group(1)}{value};"

    updated, count = pattern.subn(replace, text)
    if count < 1:
        fail(f"iOS project is missing {key}")
    return updated


def set_native_folder(text: str, slug: str) -> str:
    updated, count = re.subn(
        r'path = "\.\./flavors/[^"]+/assets/native";',
        f'path = "../flavors/{slug}/assets/native";',
        text,
        count=1,
    )
    if count != 1:
        fail("iOS project is missing the native folder reference")
    return updated


def set_entitlement_build_setting(text: str, enabled: bool) -> str:
    kept = []
    for line in text.splitlines(keepends=True):
        if "CODE_SIGN_ENTITLEMENTS" in line:
            continue
        kept.append(line)
        if enabled and line.lstrip("\t").startswith("PRODUCT_BUNDLE_IDENTIFIER"):
            indent = line[: len(line) - len(line.lstrip("\t"))]
            kept.append(f"{indent}CODE_SIGN_ENTITLEMENTS = {ENTITLEMENTS_REL};\n")
    return "".join(kept)


def set_push_capability(text: str, enabled: bool) -> str:
    pattern = re.compile(
        rf"(\t+{IOS_TARGET} = \{{\n)"
        rf"(\t+CreatedOnToolsVersion = 15\.3;\n)"
        rf"(?:\t+SystemCapabilities = \{{\n\t+com\.apple\.Push = \{{\n\t+enabled = 1;\n\t+\}};\n\t+\}};\n)?"
        rf"(\t+\}};\n)"
    )

    def replace(match: re.Match[str]) -> str:
        capability = ""
        if enabled:
            indent = re.match(r"\t+", match.group(2)).group(0)
            inner = indent + "\t"
            capability = (
                f"{indent}SystemCapabilities = {{\n"
                f"{inner}com.apple.Push = {{\n"
                f"{inner}\tenabled = 1;\n"
                f"{inner}}};\n"
                f"{indent}}};\n"
            )
        return match.group(1) + match.group(2) + capability + match.group(3)

    updated, count = pattern.subn(replace, text, count=1)
    if count != 1:
        fail("iOS project is missing the HotwireNativeShell target attributes")
    return updated


def entitlements_plist() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n'
        "<dict>\n"
        "\t<key>aps-environment</key>\n"
        "\t<string>development</string>\n"
        "</dict>\n"
        "</plist>\n"
    )


def write_ios(root: Path, spec: dict, artwork: Path) -> None:
    project = root / "ios" / "HotwireNativeShell.xcodeproj" / "project.pbxproj"
    text = project.read_text()
    text = set_pbx_setting(text, "PRODUCT_BUNDLE_IDENTIFIER", spec["application_id"])
    text = set_pbx_setting(text, "INFOPLIST_KEY_CFBundleDisplayName", pbx_quote(spec["display_name"]))
    text = set_native_folder(text, spec["slug"])
    text = set_entitlement_build_setting(text, spec["push"]["enabled"])
    text = set_push_capability(text, spec["push"]["enabled"])
    project.write_text(text)
    entitlements = root / "ios" / ENTITLEMENTS_REL
    if spec["push"]["enabled"]:
        entitlements.write_text(entitlements_plist())
    elif entitlements.is_file():
        entitlements.unlink()
    catalog = root / "ios" / "HotwireNativeShell" / "Assets.xcassets"
    (catalog / "SplashBackground.colorset" / "Contents.json").write_text(
        colorset_json(spec["colors"]["splash_background"])
    )
    (catalog / "AccentColor.colorset" / "Contents.json").write_text(colorset_json(spec["colors"]["primary"]))
    rasterize(artwork, catalog / "SplashIcon.imageset" / "splash.png", 1024)
    rasterize(
        artwork,
        catalog / "AppIcon.appiconset" / "icon.png",
        1024,
        background=spec["colors"]["splash_background"],
    )


def bridges_on(spec: dict) -> str:
    enabled = [key for key, value in spec["bridges"].items() if value]
    return ", ".join(f"`{key}`" for key in enabled) if enabled else "none"


def tab_summary(spec: dict) -> str:
    if not spec["tabs"]:
        return f"`{spec['start_path']}` only (no cold-start bar)"
    parts = []
    for tab in spec["tabs"]:
        where = tab.get("path") or tab.get("url")
        parts.append(f"{tab['title']} `{where}`")
    return ", ".join(parts)


def write_flavor_readme(root: Path, spec: dict) -> None:
    push = spec["push"]
    push_line = "off"
    if push["enabled"]:
        topics = ", ".join(f"`{topic}`" for topic in push["topics"]) or "none"
        push_line = f"on ({topics}). `google-services.json` is copied into the Android source set and gitignored."
    text = f"""# {spec['display_name']}

Generated by `bin/new-app`.

| | |
| --- | --- |
| Slug | `{spec['slug']}` |
| Android `applicationId` and iOS bundle id | `{spec['application_id']}` |
| Display name | {spec['display_name']} |
| Production origin | {spec['base_url']} |
| Dev origin (iOS simulator) | {spec['dev_base_url']} |
| Dev origin (Android emulator) | {spec['android_dev_base_url']} |
| Contract | [`assets/native/config.json`](assets/native/config.json) |
| Bridges on | {bridges_on(spec)} |
| Always registered | `menu`, `overflow-menu`, `tabs` |
| Cold-start tabs | {tab_summary(spec)} |
| Push | {push_line} |

`assets/native/config.json` uses the production origin. A debug build can point `base_url` at the dev origin locally. Put the production origin back before you ship.

Screenshot copy and capture URLs live in [`store/brand.yml`](../../store/brand.yml). See [docs/STORE_SCREENSHOTS.md](../../docs/STORE_SCREENSHOTS.md).
"""
    (root / "flavors" / spec["slug"] / "README.md").write_text(text)


def starter_brand(spec: dict, logo_rel: str) -> dict:
    display = spec["display_name"]
    home = spec["start_path"]
    url = spec["base_url"] + home

    def slide_pair(locale: str) -> dict:
        if locale == "es":
            return {
                "lang": "es",
                "folio": [display, "Edición de bolsillo", "Nº 01"],
                "pending": "Captura pendiente",
                "feature": {"headline": f"{display},<br><em>en tu bolsillo.</em>", "tag": display},
                "slides": [
                    {
                        "id": "01-home",
                        "phone": "l",
                        "theme": "ink",
                        "kicker": "Portada",
                        "headline": f"{display},<br><em>en tu bolsillo.</em>",
                        "sub": "La primera pantalla del sitio, dentro del marco.",
                        "screen": {"ipad": ["ipad_home.png"], "srcs": ["home.png"], "nav": {"title": display}},
                    },
                    {
                        "id": "02-editor",
                        "phone": "l",
                        "theme": "paper",
                        "kicker": "Editor",
                        "headline": "Escribe<br><em>donde estés.</em>",
                        "sub": "Suelta la captura con sesión iniciada. El marco dibuja la barra.",
                        "screen": {
                            "ipad": ["ipad_editor.png"],
                            "srcs": ["app_editor.png"],
                            "label": "editor",
                            "nav": {"title": "Editor", "back": True},
                        },
                    },
                ],
            }
        return {
            "lang": "en",
            "folio": [display, "Pocket edition", "No. 01"],
            "pending": "Screenshot pending",
            "feature": {"headline": f"{display},<br><em>in your pocket.</em>", "tag": display},
            "slides": [
                {
                    "id": "01-home",
                    "phone": "l",
                    "theme": "ink",
                    "kicker": "Cover",
                    "headline": f"{display},<br><em>in your pocket.</em>",
                    "sub": "The first screen of the site, inside the frame.",
                    "screen": {"ipad": ["ipad_home.png"], "srcs": ["home.png"], "nav": {"title": display}},
                },
                {
                    "id": "02-editor",
                    "phone": "l",
                    "theme": "paper",
                    "kicker": "Editor",
                    "headline": "Write<br><em>anywhere.</em>",
                    "sub": "Drop in a signed-in capture. The frame draws the status bar.",
                    "screen": {
                        "ipad": ["ipad_editor.png"],
                        "srcs": ["app_editor.png"],
                        "label": "editor",
                        "nav": {"title": "Editor", "back": True},
                    },
                },
            ],
        }

    def capture(filename: str, device: str) -> dict:
        return {
            "file": filename,
            "url": url,
            "device": device,
            "user_agent": "safari",
            "locale": "en-US",
            "steps": [{"add_class": "hotwire-native"}],
        }

    return {
        "name": spec["slug"],
        "display_name": display,
        "logo": logo_rel,
        "captures_dir": "store/captures",
        "assets_dir": "store/assets",
        "output_dir": "store/screenshots",
        "colors": {
            "ink": spec["colors"]["ink"],
            "mint": spec["colors"]["primary"],
            "blue": spec["colors"]["secondary"],
            "paper": spec["colors"]["paper"],
        },
        "fonts": {
            "display": "Bodoni Moda",
            "sans": "Archivo",
            "mono": "IBM Plex Mono",
            "ui": "Inter",
        },
        "status_time": "9:41",
        "feature_screen": "home.png",
        "feature_nav_title": display,
        "drop_ins": [
            {
                "file": "app_editor.png",
                "device": "iphone",
                "width": 1170,
                "height": 2532,
                "note": "Signed-in editor. Omit the status bar and the nav bar; the frame draws them.",
            },
            {
                "file": "ipad_editor.png",
                "device": "ipad",
                "width": 2064,
                "height": 2752,
                "note": "Same editor on the iPad 13-inch canvas (1032x1376 pt at 2x).",
            },
        ],
        "locales": {"es": slide_pair("es"), "en": slide_pair("en")},
        "captures": [capture("home.png", "iphone"), capture("ipad_home.png", "ipad")],
    }


def write_brand(root: Path, spec: dict, artwork: Path) -> str:
    brand_dir = root / "store" / "brand"
    brand_dir.mkdir(parents=True, exist_ok=True)
    extension = artwork.suffix.lower()
    if extension not in {".svg", ".png", ".jpg", ".jpeg", ".webp"}:
        extension = ".png"
    logo_name = "icon.svg" if extension == ".svg" else "icon.png"
    logo_path = brand_dir / logo_name
    if extension == ".svg":
        shutil.copyfile(artwork, logo_path)
    else:
        rasterize(artwork, logo_path, 512)
    for sibling in ("icon.svg", "icon.png"):
        other = brand_dir / sibling
        if other != logo_path and other.is_file():
            other.unlink()
    logo_rel = f"store/brand/{logo_name}"
    payload = starter_brand(spec, logo_rel)
    text = (
        "# Generated by bin/new-app. Edit copy, capture URLs, and drop-in filenames here.\n"
        "# See docs/STORE_SCREENSHOTS.md.\n"
        + yaml.safe_dump(payload, sort_keys=False, allow_unicode=True)
    )
    (root / "store" / "brand.yml").write_text(text)
    return logo_rel


def answers_document(spec: dict) -> dict:
    return {
        "display_name": spec["display_name"],
        "slug": spec["slug"],
        "application_id": spec["application_id"],
        "base_url": spec["base_url"],
        "dev_base_url": spec["dev_base_url"],
        "android_dev_base_url": spec["android_dev_base_url"],
        "colors": spec["colors"],
        "icon": spec["icon"],
        "start_path": spec["start_path"],
        "tabs": spec["tabs"],
        "bridges": spec["bridges"],
        "push": spec["push"],
    }


def checklist(spec: dict) -> str:
    slug = spec["slug"]
    task = f"assemble{slug[:1].upper()}{slug[1:]}Debug"
    lines = [
        "",
        "Manual steps left",
        "",
        "1. Xcode signing. Open ios/HotwireNativeShell.xcodeproj, select the HotwireNativeShell "
        "target, and pick a Team under Signing & Capabilities. Do not commit the team id, a "
        "provisioning profile, or a .p12.",
        "2. Rails. Serve GET /native/config, GET /configurations/android_v1.json, and "
        "GET /configurations/ios_v1.json from "
        f"{spec['base_url']}. Start from rails-example/ and docs/CONTRACT.md. Install the Stimulus "
        f"controllers for the bridges you turned on ({bridges_on(spec)}). menu, overflow-menu, and "
        "tabs are already registered.",
        "3. Dev origins stay out of the shipped JSON. iOS Simulator: "
        f"{spec['dev_base_url']}. Android emulator: {spec['android_dev_base_url']}. "
        f"The bundled base_url is {spec['base_url']}.",
        "4. Store screenshots. Edit store/brand.yml (copy, capture URLs, drop-ins such as "
        "app_editor.png and ipad_editor.png), then follow docs/STORE_SCREENSHOTS.md.",
        f"5. Build this client only: cd android && ./gradlew :app:{task}",
    ]
    if spec["push"]["enabled"]:
        lines.append(
            "6. Firebase. google-services.json is copied to "
            f"android/app/src/{slug}/google-services.json and is gitignored. Confirm the Firebase "
            "project, then add the Google services Gradle plugin and FCM when this client should "
            "mint a real device token. This skeleton still replies with the placeholder token until "
            "that dependency is added. Do not commit the JSON file."
        )
        lines.append(
            "7. APNs. The Xcode target now has the Push Notifications capability "
            "(aps-environment = development). Create an APNs key in Apple Developer and upload it "
            "to the Rails app. Switch the entitlement to production when you archive for the App Store."
        )
    else:
        lines.append(
            "6. Push is off. Leave the Google services plugin, google-services.json, and the APNs "
            "entitlement unset. If notification_token is on, the bridge still returns "
            "placeholder-not-a-device-token."
        )
    return "\n".join(lines) + "\n"


def require_push_file(spec: dict, root: Path) -> Path | None:
    if not spec["push"]["enabled"]:
        return None
    raw = spec["push"]["google_services_json"]
    if not raw:
        fail("push is enabled; set push.google_services_json to the Firebase Android config")
    found = resolve_existing(raw, root)
    if found is None:
        fail(f"google-services.json not found: {raw}")
    try:
        parsed = json.loads(found.read_text())
    except json.JSONDecodeError as exc:
        fail(f"google-services.json is not JSON: {exc}")
    if not isinstance(parsed, dict):
        fail("google-services.json must be a JSON object")
    return found


def apply(spec: dict, root: Path, *, skip_ios: bool, keep_brand: bool, dry_run: bool) -> None:
    if not spec["icon"]:
        fail("icon is required (image file or favicon URL)")
    services = require_push_file(spec, root)
    with tempfile.TemporaryDirectory() as tmp:
        artwork = materialize_icon(spec["icon"], root, Path(tmp))
        if dry_run:
            print(f"dry run: would write flavors/{spec['slug']}, Android flavor, store/brand.yml")
            if not skip_ios:
                print("dry run: would retarget ios/HotwireNativeShell.xcodeproj")
            if spec["push"]["enabled"]:
                print(f"dry run: would copy {services} into android/app/src/{spec['slug']}/")
                print("dry run: would enable the iOS Push Notifications entitlement")
            print(config_json(spec), end="")
            print(checklist(spec), end="")
            return
        flavor = root / "flavors" / spec["slug"]
        native = flavor / "assets" / "native"
        native.mkdir(parents=True, exist_ok=True)
        (native / "config.json").write_text(config_json(spec))
        (flavor / "app.yml").write_text(
            "# Answers for bin/new-app. Re-run: bin/new-app --file flavors/"
            f"{spec['slug']}/app.yml\n"
            + yaml.safe_dump(answers_document(spec), sort_keys=False, allow_unicode=True)
        )
        write_flavor_readme(root, spec)
        write_gradle(root, spec)
        write_android_resources(root, spec, artwork)
        if services is not None:
            dest = root / "android" / "app" / "src" / spec["slug"] / "google-services.json"
            dest.parent.mkdir(parents=True, exist_ok=True)
            if services.resolve() != dest.resolve():
                shutil.copyfile(services, dest)
        if not skip_ios:
            write_ios(root, spec, artwork)
        if not keep_brand:
            write_brand(root, spec, artwork)
        print(f"Wrote flavors/{spec['slug']}/assets/native/config.json")
        print(f"Wrote Android flavor {spec['slug']} ({spec['application_id']})")
        if not skip_ios:
            print(f"Pointed the iOS target at flavors/{spec['slug']} ({spec['application_id']})")
        if not keep_brand:
            print("Wrote store/brand.yml")
        print(checklist(spec), end="")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Create a Hotwire Native client flavor.")
    parser.add_argument("--file", "-f", type=Path, help="Non-interactive answers (app.yml).")
    parser.add_argument("--config-only", action="store_true", help="Print native/config.json and exit.")
    parser.add_argument("--dry-run", action="store_true", help="Validate and print actions without writing.")
    parser.add_argument("--skip-ios", action="store_true", help="Do not retarget the single iOS app.")
    parser.add_argument("--keep-brand", action="store_true", help="Do not rewrite store/brand.yml.")
    parser.add_argument("--root", type=Path, help="Repository root. Defaults to this repo.")
    args = parser.parse_args(argv)
    root = (args.root or repo_root()).resolve()
    try:
        if args.file:
            spec = normalize(load_yaml(args.file if args.file.is_absolute() else (Path.cwd() / args.file).resolve()))
        elif args.config_only or args.dry_run:
            fail("pass --file for a non-interactive run")
        else:
            spec = prompt_spec()
        if args.config_only:
            sys.stdout.write(config_json(spec))
            return 0
        apply(spec, root, skip_ios=args.skip_ios, keep_brand=args.keep_brand, dry_run=args.dry_run)
    except AppError as exc:
        print(f"new-app: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
