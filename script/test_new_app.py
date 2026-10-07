#!/usr/bin/env python3
"""Generate a throwaway flavor, build it, and check the contract.

Restores the itsjustmy iOS target and store/brand.yml before exiting.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
NEW_APP = ROOT / "bin" / "new-app"
SLUG = "newappprobe"
APP_ID = "app.newappprobe.test"

SNAPSHOTS = [
    ROOT / "android" / "app" / "build.gradle.kts",
    ROOT / "ios" / "HotwireNativeShell.xcodeproj" / "project.pbxproj",
    ROOT / "ios" / "HotwireNativeShell" / "Assets.xcassets" / "SplashBackground.colorset" / "Contents.json",
    ROOT / "ios" / "HotwireNativeShell" / "Assets.xcassets" / "AccentColor.colorset" / "Contents.json",
    ROOT / "ios" / "HotwireNativeShell" / "Assets.xcassets" / "SplashIcon.imageset" / "splash.png",
    ROOT / "ios" / "HotwireNativeShell" / "Assets.xcassets" / "AppIcon.appiconset" / "icon.png",
    ROOT / "store" / "brand.yml",
    ROOT / "store" / "brand" / "icon.svg",
    ROOT / "ios" / "HotwireNativeShell" / "HotwireNativeShell.entitlements",
]


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, check=False, cwd=ROOT, text=True, **kwargs)


def fail(message: str) -> None:
    print(f"test_new_app: {message}", file=sys.stderr)
    sys.exit(1)


def generated_config_matches() -> None:
    result = run([sys.executable, str(NEW_APP), "--file", "flavors/itsjustmy/app.yml", "--config-only"], capture_output=True)
    if result.returncode != 0:
        fail(result.stderr)
    expected = json.loads((ROOT / "flavors" / "itsjustmy" / "assets" / "native" / "config.json").read_text())
    actual = json.loads(result.stdout)
    if actual != expected:
        fail("generated itsjustmy config does not match flavors/itsjustmy/assets/native/config.json")
    print("itsjustmy config match")


def reject_bad_input() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "bad.yml"
        path.write_text("display_name: Bad\nslug: Bad-Slug\napplication_id: app.bad\nbase_url: https://example.com\ndev_base_url: http://localhost:9292\n")
        result = run([sys.executable, str(NEW_APP), "--file", str(path), "--config-only"], capture_output=True)
        if result.returncode == 0:
            fail("bad slug was accepted")
    print("bad slug rejected")


def ensure_sdk() -> bool:
    local = ROOT / "android" / "local.properties"
    if local.is_file() and "sdk.dir" in local.read_text():
        return True
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    home = Path.home() / "android-sdk"
    if not sdk and (home / "platforms").is_dir():
        sdk = str(home)
    if not sdk:
        print("Android SDK not found; skip assemble")
        return False
    local.write_text(f"sdk.dir={sdk}\n")
    return True


def main() -> None:
    generated_config_matches()
    reject_bad_input()
    saved = {path: path.read_bytes() if path.is_file() else None for path in SNAPSHOTS}
    icon = Path(tempfile.mkdtemp()) / "icon.png"
    Image.new("RGB", (64, 64), (110, 231, 183)).save(icon)
    services = Path(tempfile.mkdtemp()) / "google-services.json"
    services.write_text('{"project_info":{"project_id":"newappprobe"},"client":[],"configuration_version":"1"}\n')
    answers = Path(tempfile.mkdtemp()) / "app.yml"
    answers.write_text(
        f"""
display_name: Probe
slug: {SLUG}
application_id: {APP_ID}
base_url: https://probe.example
dev_base_url: http://localhost:9292
android_dev_base_url: http://10.0.2.2:9292
colors:
  primary: "#112233"
  secondary: "#445566"
  ink: "#0F172A"
  paper: "#F6F2E8"
  splash_background: "#FFFFFF"
icon: {icon}
start_path: /
tabs:
  - id: home
    title: Home
    path: /
    icon: home
  - id: about
    title: About
    titles:
      en: About
      es: Acerca
    path: /about
    icon: info
bridges:
  share: true
push:
  enabled: true
  topics: [news]
  google_services_json: {services}
"""
    )
    try:
        result = run([sys.executable, str(NEW_APP), "--file", str(answers)])
        if result.returncode != 0:
            fail("new-app apply failed")
        config = json.loads((ROOT / "flavors" / SLUG / "assets" / "native" / "config.json").read_text())
        if config["name"] != SLUG or config["base_url"] != "https://probe.example":
            fail("probe config")
        if config["bridges"]["share"] is not True or config["bridges"]["haptic"] is not False:
            fail("probe bridges")
        if config["push"] != {"enabled": True, "topics": ["news"]}:
            fail("probe push")
        gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()
        if f'applicationId = "{APP_ID}"' not in gradle or f"../flavors/{SLUG}/assets" not in gradle:
            fail("gradle wiring")
        project = (ROOT / "ios" / "HotwireNativeShell.xcodeproj" / "project.pbxproj").read_text()
        if f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID};" not in project:
            fail("ios bundle id")
        if f"../flavors/{SLUG}/assets/native" not in project:
            fail("ios native folder")
        if project.count("CODE_SIGN_ENTITLEMENTS") != 2 or "com.apple.Push" not in project:
            fail("ios push capability")
        entitlements = (ROOT / "ios" / "HotwireNativeShell" / "HotwireNativeShell.entitlements").read_text()
        if "aps-environment" not in entitlements:
            fail("aps-environment")
        services_copy = ROOT / "android" / "app" / "src" / SLUG / "google-services.json"
        if not services_copy.is_file():
            fail("google-services.json was not copied")
        brand = (ROOT / "store" / "brand.yml").read_text()
        if "app_editor.png" not in brand or "ipad_editor.png" not in brand or "#112233" not in brand:
            fail("starter brand.yml")
        strings = (ROOT / "android" / "app" / "src" / SLUG / "res" / "values" / "strings.xml").read_text()
        if ">Probe<" not in strings:
            fail("android app_name")
        again = run([sys.executable, str(NEW_APP), "--file", str(answers)])
        if again.returncode != 0:
            fail("second new-app apply failed")
        gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()
        if gradle.count(f'create("{SLUG}")') != 1:
            fail("gradle flavor was duplicated")
        check = run([sys.executable, str(ROOT / "script" / "check_contract.py"), "--flavor", SLUG], capture_output=True)
        if check.returncode != 0:
            fail(check.stderr)
        print(check.stdout.strip())
        if ensure_sdk():
            task = f":app:assemble{SLUG[:1].upper()}{SLUG[1:]}Debug"
            build = subprocess.run(["./gradlew", task], cwd=ROOT / "android", check=False)
            apk = ROOT / "android" / "app" / "build" / "outputs" / "apk" / SLUG / "debug" / f"app-{SLUG}-debug.apk"
            if build.returncode != 0 or not apk.is_file():
                fail(f"android build failed ({apk})")
            print(f"built {apk.relative_to(ROOT)}")
    finally:
        for path, data in saved.items():
            if data is None:
                if path.is_file():
                    path.unlink()
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        shutil.rmtree(ROOT / "flavors" / SLUG, ignore_errors=True)
        shutil.rmtree(ROOT / "android" / "app" / "src" / SLUG, ignore_errors=True)
        icon_png = ROOT / "store" / "brand" / "icon.png"
        if icon_png.is_file():
            icon_png.unlink()

    pilot = run([sys.executable, str(ROOT / "script" / "check_contract.py")], capture_output=True)
    if pilot.returncode != 0:
        fail(pilot.stderr)
    print(pilot.stdout.strip())
    itsjustmy = run([sys.executable, str(ROOT / "script" / "check_contract.py"), "--flavor", "itsjustmy"], capture_output=True)
    if itsjustmy.returncode != 0:
        fail(itsjustmy.stderr)
    print(itsjustmy.stdout.strip())
    print("test_new_app ok")


if __name__ == "__main__":
    main()
