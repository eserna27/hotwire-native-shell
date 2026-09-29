#!/usr/bin/env python3
"""Check the itsjustmy contract file and the files that must keep pointing at it."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "flavors" / "itsjustmy" / "assets" / "native" / "config.json"
PATH_CONFIG = ROOT / "android" / "app" / "src" / "main" / "assets" / "json" / "path-configuration.json"

EXPECTED_BRIDGE_KEYS = [
    "notification_token",
    "share",
    "haptic",
    "camera",
    "biometric",
    "clipboard",
    "file_download",
]


def fail(message: str) -> None:
    print(f"contract check failed: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    config = json.loads(CONFIG_PATH.read_text())
    if config["name"] != "itsjustmy":
        fail("name")
    if config["base_url"] != "https://itsjustmy.blog":
        fail("base_url")
    if config["start_path"] != "/":
        fail("start_path")
    if config["tabs"] != []:
        fail("tabs")
    bridges = config["bridges"]
    if list(bridges) != EXPECTED_BRIDGE_KEYS:
        fail(f"bridge keys {list(bridges)}")
    if bridges["notification_token"] is not True or bridges["share"] is not True or bridges["haptic"] is not True:
        fail("expected notification_token, share, and haptic on")
    for key in ("camera", "biometric", "clipboard", "file_download"):
        if bridges[key] is not False:
            fail(f"{key} should be off")
    if config["push"] != {"enabled": True, "topics": ["posts"]}:
        fail("push")

    path_configuration = json.loads(PATH_CONFIG.read_text())
    if "settings" not in path_configuration or "rules" not in path_configuration:
        fail("path configuration needs settings and rules")
    uris = [
        rule["properties"].get("uri")
        for rule in path_configuration["rules"]
        if "uri" in rule.get("properties", {})
    ]
    if "hotwire://fragment/web" not in uris or "hotwire://fragment/web/modal/sheet" not in uris:
        fail("path configuration uris")

    gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()
    if 'applicationId = "blog.itsjustmy.app"' not in gradle:
        fail("applicationId")
    if "../flavors/itsjustmy/assets" not in gradle:
        fail("flavor assets are not wired into the Android source set")
    if "dev.hotwire:core:1.3.1" not in gradle or "dev.hotwire:navigation-fragments:1.3.1" not in gradle:
        fail("Hotwire Native Android 1.3.1")

    registrar = (ROOT / "android" / "app" / "src" / "main" / "kotlin" / "dev" / "hotwire" / "nativeshell" / "bridge" / "BridgeRegistrar.kt").read_text()
    for component in ("notification-token", "share", "haptic", "menu", "overflow-menu"):
        if f'"{component}"' not in registrar:
            fail(f"missing bridge registration {component}")

    ruby = (ROOT / "rails-example" / "lib" / "native_config.rb").read_text()
    if "flavors/itsjustmy/assets/native/config.json" not in ruby:
        fail("rails sketch does not read the flavor JSON")

    ios_project = (ROOT / "ios" / "HotwireNativeShell.xcodeproj" / "project.pbxproj").read_text()
    if "PRODUCT_BUNDLE_IDENTIFIER = blog.itsjustmy.app;" not in ios_project:
        fail("iOS bundle id")
    if ios_project.count("INFOPLIST_KEY_CFBundleDisplayName = itsjustmy.blog;") != 2:
        fail("iOS display name")
    android_name = (ROOT / "android" / "app" / "src" / "itsjustmy" / "res" / "values" / "strings.xml").read_text()
    if "<string name=\"app_name\">itsjustmy.blog</string>" not in android_name:
        fail("Android app_name")
    if "https://github.com/hotwired/hotwire-native-ios" not in ios_project or "version = 1.3.1;" not in ios_project:
        fail("Hotwire Native iOS 1.3.1")
    if "../flavors/itsjustmy/assets/native" not in ios_project:
        fail("iOS flavor folder reference")
    if "CODE_SIGN_ENTITLEMENTS" in ios_project or "aps-environment" in ios_project:
        fail("iOS push entitlement")

    scheme = ROOT / "ios" / "HotwireNativeShell.xcodeproj" / "xcshareddata" / "xcschemes" / "HotwireNativeShell.xcscheme"
    if not scheme.is_file():
        fail("missing HotwireNativeShell scheme")

    ios_path = ROOT / "ios" / "HotwireNativeShell" / "path-configuration.json"
    ios_rules = json.loads(ios_path.read_text())
    if "settings" not in ios_rules or "rules" not in ios_rules:
        fail("iOS path configuration needs settings and rules")
    contexts = [rule["properties"].get("context") for rule in ios_rules["rules"]]
    if "default" not in contexts or "modal" not in contexts:
        fail("iOS path configuration contexts")

    bridge_dir = ROOT / "ios" / "HotwireNativeShell" / "Bridge"
    bridge_swift = "\n".join(path.read_text() for path in bridge_dir.glob("*.swift"))
    for component in ("notification-token", "share", "haptic", "menu", "overflow-menu"):
        if f'"{component}"' not in bridge_swift:
            fail(f"missing iOS bridge registration {component}")
    registrar_swift = (bridge_dir / "BridgeRegistrar.swift").read_text()
    for component_type in (
        "NotificationTokenComponent",
        "ShareComponent",
        "HapticComponent",
        "MenuComponent",
        "OverflowMenuComponent",
    ):
        if f"{component_type}.self" not in registrar_swift:
            fail(f"missing iOS bridge type {component_type}")
    native_ui = ROOT / "docs" / "NATIVE_UI.md"
    if not native_ui.is_file():
        fail("missing docs/NATIVE_UI.md")
    native_ui_text = native_ui.read_text()
    if "Hotwire Native" not in native_ui_text or "itsjustmy.blog" not in native_ui_text:
        fail("native UI doc missing detection or title suffix")
    if "nav.navbar" not in native_ui_text:
        fail("native UI doc missing navbar hide target")

    token_swift = (ROOT / "ios" / "HotwireNativeShell" / "Bridge" / "NotificationTokenComponent.swift").read_text()
    if "placeholder-not-a-device-token" not in token_swift or '"placeholder"' not in token_swift:
        fail("iOS placeholder notification token")

    app_delegate = (ROOT / "ios" / "HotwireNativeShell" / "AppDelegate.swift").read_text()
    if "/configurations/ios_v1.json" not in app_delegate:
        fail("iOS path configuration URL")
    scene = (ROOT / "ios" / "HotwireNativeShell" / "SceneDelegate.swift").read_text()
    if "Navigator(" not in scene or "startLocation" not in scene:
        fail("iOS navigator start")

    debug_plist = (ROOT / "ios" / "HotwireNativeShell" / "Info-Debug.plist").read_text()
    release_plist = (ROOT / "ios" / "HotwireNativeShell" / "Info.plist").read_text()
    if "localhost" not in debug_plist or "NSExceptionAllowsInsecureHTTPLoads" not in debug_plist:
        fail("debug ATS localhost exception")
    if "NSAllowsArbitraryLoads" in release_plist or "NSExceptionAllowsInsecureHTTPLoads" in release_plist:
        fail("release plist allows cleartext")
    if "NSAllowsArbitraryLoads" in debug_plist:
        fail("debug plist allows arbitrary cleartext")

    for secret_name in ("*.p12", "*.mobileprovision", "*.entitlements", "google-services.json"):
        if list((ROOT / "ios").glob(secret_name)):
            fail(f"secret in ios: {secret_name}")

    print("contract check ok")


if __name__ == "__main__":
    main()
