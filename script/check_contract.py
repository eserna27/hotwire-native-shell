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
    tabs = config["tabs"]
    expected_tabs = [
        {
            "id": "home",
            "title": "Inicio",
            "titles": {"es": "Inicio", "en": "Home"},
            "path": "/",
            "icon": "home",
        },
        {
            "id": "about",
            "title": "Acerca",
            "titles": {"es": "Acerca", "en": "About"},
            "path": "/acerca",
            "icon": "info",
            "sf_symbol": "info.circle",
        },
        {
            "id": "sign_in",
            "title": "Entrar",
            "titles": {"es": "Entrar", "en": "Sign in"},
            "path": "/users/sign_in",
            "icon": "profile",
            "android_icon": "ic_tab_profile",
        },
    ]
    if tabs != expected_tabs:
        fail(f"tabs {tabs}")
    if len(tabs) < 2 or len(tabs) > 5:
        fail("tab count")
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

    kotlin_config = (
        ROOT / "android" / "app" / "src" / "main" / "kotlin" / "dev" / "hotwire" / "nativeshell" / "config" / "NativeConfig.kt"
    ).read_text()
    if "const val MAX_TABS = 5" not in kotlin_config:
        fail("Android tab cap")
    if "sf_symbol" not in kotlin_config or "android_icon" not in kotlin_config:
        fail("Android tab icon fields")
    shell_tabs = (
        ROOT / "android" / "app" / "src" / "main" / "kotlin" / "dev" / "hotwire" / "nativeshell" / "config" / "ShellTabs.kt"
    ).read_text()
    for drawable in ("ic_tab_home", "ic_tab_posts", "ic_tab_search", "ic_tab_profile", "ic_tab_info"):
        if drawable not in shell_tabs:
            fail(f"missing Android tab icon {drawable}")
    main_activity = (
        ROOT / "android" / "app" / "src" / "main" / "kotlin" / "dev" / "hotwire" / "nativeshell" / "MainActivity.kt"
    ).read_text()
    if "resolution.tabs.size < 2" not in main_activity or "HotwireBottomNavigationController" not in main_activity:
        fail("Android tab bar fallback")
    tabs_layout = (ROOT / "android" / "app" / "src" / "main" / "res" / "layout" / "activity_main_tabs.xml").read_text()
    for host in ("tab_host_0", "tab_host_1", "tab_host_2", "tab_host_3", "tab_host_4"):
        if f"@+id/{host}" not in tabs_layout:
            fail(f"missing {host}")
    if not (ROOT / "android" / "app" / "src" / "main" / "res" / "drawable" / "ic_tab_info.xml").is_file():
        fail("missing ic_tab_info")

    ios_config = (ROOT / "ios" / "HotwireNativeShell" / "Config" / "NativeConfig.swift").read_text()
    if "static let maxTabs = 5" not in ios_config:
        fail("iOS tab cap")
    scene = (ROOT / "ios" / "HotwireNativeShell" / "SceneDelegate.swift").read_text()
    if "resolution.tabs.count < 2" not in scene or "HotwireTabBarController" not in scene:
        fail("iOS tab bar fallback")
    ios_tabs = (ROOT / "ios" / "HotwireNativeShell" / "Config" / "ShellTabs.swift").read_text()
    for symbol in ("house", "doc.text", "magnifyingglass", "person", "info.circle"):
        if symbol not in ios_tabs:
            fail(f"missing iOS tab symbol {symbol}")

    contract = (ROOT / "docs" / "CONTRACT.md").read_text()
    for phrase in ("sf_symbol", "android_icon", "HotwireBottomNavigationController", "HotwireTabBarController", "at most five"):
        if phrase not in contract:
            fail(f"contract missing {phrase}")
    native_ui = (ROOT / "docs" / "NATIVE_UI.md").read_text()
    if "Bottom tabs" not in native_ui or "overflow-menu" not in native_ui or "bridge--tabs" not in native_ui:
        fail("native UI tabs section")
    bridges_doc = (ROOT / "docs" / "BRIDGES.md").read_text()
    if 'static component = "tabs"' not in bridges_doc:
        fail("bridges doc missing tabs controller")

    gradle = (ROOT / "android" / "app" / "build.gradle.kts").read_text()
    if 'applicationId = "blog.itsjustmy.app"' not in gradle:
        fail("applicationId")
    if "../flavors/itsjustmy/assets" not in gradle:
        fail("flavor assets are not wired into the Android source set")
    if "dev.hotwire:core:1.3.1" not in gradle or "dev.hotwire:navigation-fragments:1.3.1" not in gradle:
        fail("Hotwire Native Android 1.3.1")

    registrar = (ROOT / "android" / "app" / "src" / "main" / "kotlin" / "dev" / "hotwire" / "nativeshell" / "bridge" / "BridgeRegistrar.kt").read_text()
    for component in ("notification-token", "share", "haptic", "menu", "overflow-menu", "tabs"):
        if f'"{component}"' not in registrar:
            fail(f"missing bridge registration {component}")
    if not (
        ROOT / "android" / "app" / "src" / "main" / "kotlin" / "dev" / "hotwire" / "nativeshell" / "bridge" / "TabsComponent.kt"
    ).is_file():
        fail("missing Android TabsComponent")

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
    if "TabsComponent.swift in Sources" not in ios_project:
        fail("iOS TabsComponent is not in the target")
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
    for component in ("notification-token", "share", "haptic", "menu", "overflow-menu", "tabs"):
        if f'"{component}"' not in bridge_swift:
            fail(f"missing iOS bridge registration {component}")
    registrar_swift = (bridge_dir / "BridgeRegistrar.swift").read_text()
    for component_type in (
        "NotificationTokenComponent",
        "ShareComponent",
        "HapticComponent",
        "MenuComponent",
        "OverflowMenuComponent",
        "TabsComponent",
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
