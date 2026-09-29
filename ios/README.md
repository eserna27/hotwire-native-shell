# iOS shell

Hotwire Native iOS app. Open `ios/HotwireNativeShell.xcodeproj` in Xcode 15 or newer. The shared scheme is `HotwireNativeShell`.

Pinned to [Hotwire Native iOS 1.3.1](https://github.com/hotwired/hotwire-native-ios/releases/tag/1.3.1) (`HotwireNative` via Swift Package Manager), the same release line as the Android shell. The app follows that project's demo: a UIKit `SceneDelegate`, `Navigator`, `Hotwire.loadPathConfiguration(from:)`, and `BridgeComponent` subclasses registered with `Hotwire.registerBridgeComponents`. Deployment target is iOS 15.6.

The pilot bundle id is `blog.itsjustmy.app`. The home screen name is **itsjustmy**. The icon is a placeholder monogram.

## Build

On a Mac, with Xcode selected:

```sh
cd ios
xcodebuild \
  -project HotwireNativeShell.xcodeproj \
  -scheme HotwireNativeShell \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Product → Run in Xcode launches the same scheme in the simulator. No signing certificate, provisioning profile, or development team is in git. Automatic signing is on so a device build can use a team you select locally in Signing & Capabilities. Do not commit that team id, a `.p12`, or a provisioning profile.

`xcodebuild` needs macOS and Xcode. A Linux checkout cannot compile this target. `python3 script/check_contract.py` from the repo root still checks that the bundled contract, bundle id, and bridge names are wired up.

## What it does

1. `AppDelegate` reads `native/config.json` from the app bundle. That folder reference is [`flavors/itsjustmy/assets/native`](../flavors/itsjustmy/assets/native), the same file Android packages.
2. It registers `notification-token`, `share`, and `haptic` because that file turns them on. There is no push entitlement and no APNs token. The notification bridge returns `placeholder-not-a-device-token`.
3. It loads Hotwire path configuration from `path-configuration.json`, then tries `{base_url}/configurations/ios_v1.json`. Hotwire keeps the bundled rules when the remote URL 404s.
4. `SceneDelegate` opens `base_url` + `start_path` in a `Navigator`. itsjustmy has no tabs, so there is no tab bar. A config with `tabs` uses `HotwireTabBarController` (at most four tabs, same cap as Android).
5. A background request stores `GET /native/config`. The cache is used on the next cold start. If the site does not serve the route yet, the bundled JSON stays in effect.

`push.enabled` and `push.topics` are logged at startup and are not subscribed.

Hotwire debug logging is on in debug builds only.

## Local Rails sketch

Debug builds allow cleartext HTTP to `localhost` and `127.0.0.1` only (`Info-Debug.plist`). Release builds do not. The iOS Simulator uses the Mac's loopback, so point `base_url` at `http://localhost:9292` to hit `rails-example`. Put the production origin back before you ship.

The Android emulator still uses `http://10.0.2.2:9292`. See [android/README.md](../android/README.md).

## Another client

v1 is this one target. Swap the bundle id, the display name, and the `native` folder reference. Steps are in [docs/NEW_APP.md](../docs/NEW_APP.md).
