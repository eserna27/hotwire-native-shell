# AGENTS.md

> Playbook para agentes: cómo construir o extender una app cliente a partir de este shell Hotwire Native.

This file is the single entry point for coding agents (Cursor cloud agents, Grok Bot, and others). Follow the linked docs. Do not copy them into a second contract.

## What this repo is

A reusable [Hotwire Native](https://native.hotwired.dev/) shell. Android and iOS. The native app is a thin container. Rails serves `GET /native/config` and decides the origin, the start path, and which bridge components are on.

MIT licensed, for our own apps (itsjustmy, Nagama, Jazz). It is not a product to sell. Each Rails site stays in its own repository and only needs to serve the contract.

## Do not

- Clone or fork this repo per client. On Android a client is a Gradle flavor plus `flavors/<name>/`. On iOS v1, keep the one Xcode target and swap the bundle id plus the bundled flavor folder. See [docs/NEW_APP.md](docs/NEW_APP.md).
- Invent a different JSON contract, rename existing fields, or add a second config endpoint. A new key is allowed only when an already-shipped shell can ignore it. Field rules live in [docs/CONTRACT.md](docs/CONTRACT.md).
- Commit secrets: keystores (`*.jks`, `*.keystore`), `keystore.properties`, `google-services.json`, API keys, signing passwords, `.p12` files, or provisioning profiles. Those paths are gitignored.
- Add Firebase Cloud Messaging, the Google services plugin, or `google-services.json` unless the task explicitly asks for FCM on a named client.
- Add an APNs entitlement, a push capability, or a signing identity by hand. The committed Xcode project has no push entitlement on purpose. [bin/new-app](bin/new-app) writes the Push Notifications entitlement only when that client's answers turn push on, and only on the single iOS target. Do not leave that entitlement on the itsjustmy pilot.

## Reading order

1. [README.md](README.md) — what the shell is and is not.
2. [docs/CONTRACT.md](docs/CONTRACT.md) — `GET /native/config` and path configuration.
3. [docs/BRIDGES.md](docs/BRIDGES.md) — bridge catalog and the placeholder notification token.
4. [docs/NATIVE_UI.md](docs/NATIVE_UI.md) — native bar, the HTML navbar the Rails app must hide, and document titles.
5. [docs/NEW_APP.md](docs/NEW_APP.md) — add a client flavor.
6. [android/README.md](android/README.md) — toolchain, build, signing, emulator cleartext.
7. [ios/README.md](ios/README.md) — Xcode scheme, simulator build, localhost cleartext.
8. [rails-example/](rails-example/README.md) — sketch that serves the contract without a full Rails app.
9. [rails/README.md](rails/README.md) — `hotwire_native_shell-rails`, the gem a real Rails app installs.
10. [bin/new-app](bin/new-app) — questionnaire (or `app.yml`) that writes a flavor. See [docs/NEW_APP.md](docs/NEW_APP.md).
11. [docs/STORE_SCREENSHOTS.md](docs/STORE_SCREENSHOTS.md) — App Store and Play posters from [store/brand.yml](store/brand.yml).

Also: [flavors/itsjustmy/README.md](flavors/itsjustmy/README.md), [CONTRIBUTING.md](CONTRIBUTING.md).

## Pilot: itsjustmy

| | |
| --- | --- |
| Flavor | `itsjustmy` in `android/app/build.gradle.kts` (`flavorDimensions` `client`) |
| Android `applicationId` and iOS bundle id | `blog.itsjustmy.app` |
| `base_url` | `https://itsjustmy.blog` |
| Flavor directory | `flavors/itsjustmy/` |
| Bundled contract | `flavors/itsjustmy/assets/native/config.json` (Android assets and the iOS `native` folder reference) |
| Launcher name and icon | `android/app/src/itsjustmy/` and the iOS target (`app_name` / `CFBundleDisplayName` is **itsjustmy.blog**) |
| iOS project | `ios/HotwireNativeShell.xcodeproj`, scheme `HotwireNativeShell` |

Open `android/` in Android Studio. JDK 17 or newer.

```sh
cd android
./gradlew :app:assembleItsjustmyDebug
```

Debug APK: `android/app/build/outputs/apk/itsjustmy/debug/app-itsjustmy-debug.apk`.

`./gradlew assembleDebug` builds every flavor. Use the task above when you only need the pilot.

Without the Android SDK, `python3 script/check_contract.py` checks the itsjustmy JSON shape and that the iOS target still points at it.

iOS, on a Mac with Xcode 15 or newer:

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

`xcodebuild` does not run on Linux. Do not add a development team, a provisioning profile, or a push entitlement to make the command look green.

## Adding a new app

Prefer [bin/new-app](bin/new-app) (`--file app.yml` for a non-interactive run). It follows the checklist below and prints the manual steps it cannot do (Xcode signing, the APNs key in the Rails app, the Firebase project). Hand steps, if you are not using the command, are in [docs/NEW_APP.md](docs/NEW_APP.md).

Checklist:

1. Copy `flavors/itsjustmy` to `flavors/<name>`.
2. Edit `flavors/<name>/assets/native/config.json`: `name`, `base_url`, `start_path`, optional cold-start `tabs`, `bridges`, and `push`. Leave bridge flags you are not using set to `false`.
3. In `android/app/build.gradle.kts`, next to `itsjustmy`, add a product flavor on dimension `client` with that client's `applicationId`, and set `assets.srcDir` to `../flavors/<name>/assets`.
4. Add `android/app/src/<name>/res/values/strings.xml` with `app_name`, and a launcher icon. Copy the itsjustmy launcher assets until that client has its own icon. The splash icon is `res/drawable/ic_splash.xml` (itsjustmy layers the launcher artwork) and the splash color is `@color/splash_background` in that flavor's `colors.xml`. On iOS, replace `SplashIcon` and `SplashBackground` in the asset catalog. See [docs/NEW_APP.md](docs/NEW_APP.md).
5. That client's Rails app installs [rails/](rails/README.md) (`hotwire_native_shell-rails`) so it serves `GET /native/config`, `GET /configurations/android_v1.json`, and `GET /configurations/ios_v1.json`. The JSON must match [docs/CONTRACT.md](docs/CONTRACT.md). The [rails-example/](rails-example/README.md) sketch is only the curl demo.
6. Build that flavor only. Gradle capitalizes the flavor in the task name: `cd android && ./gradlew :app:assembleNagamaDebug` for a flavor named `nagama`.
7. For iOS v1, point the existing target at the new flavor instead of adding a second app target. See [docs/NEW_APP.md](docs/NEW_APP.md).

## Rails contract reminders

- Path configuration is a separate document from `/native/config`. Android requests `GET /configurations/android_v1.json`. iOS requests `GET /configurations/ios_v1.json`. Bundled copies: `android/app/src/main/assets/json/path-configuration.json` and `ios/HotwireNativeShell/path-configuration.json`. A 404 on the remote URL is acceptable; the app keeps the bundled rules. iOS ignores the Android `uri` property.
- Bottom tabs come from the always-registered `tabs` bridge. Rails declares them in page markup (id, title, icon, path, and which one is active). `tabs` on `/native/config` is only the optional list shown before the first page connects. Two or more usable items show a native bar (one navigator per tab). Fewer than two keeps the single navigator. The cap is five. Field rules are in [docs/CONTRACT.md](docs/CONTRACT.md). The controller and markup are in [docs/BRIDGES.md](docs/BRIDGES.md) and [docs/NATIVE_UI.md](docs/NATIVE_UI.md). Android must keep `R.id.main_nav_host` in `navigatorConfigurations()` across recreate, including when the bottom bar is showing.
- The bridge catalog is fixed in the shell and toggled by JSON. Keys: `notification_token`, `share`, `haptic`, `camera`, `biometric`, `clipboard`, `file_download`. The Stimulus component name is not always the JSON key (`notification-token`, `file-download`). `menu`, `overflow-menu`, and `tabs` are always registered and are not JSON keys. See [docs/BRIDGES.md](docs/BRIDGES.md) and [docs/NATIVE_UI.md](docs/NATIVE_UI.md).
- Until a real push provider is added for that client, `notification-token` replies with `{ "token": "placeholder-not-a-device-token", "provider": "placeholder" }` on Android and iOS. Rails must ignore that string. `push.enabled` and `push.topics` are recorded at startup and are not subscribed. There is no FCM dependency and no APNs entitlement.

## Success criteria

An agent task on this repo is done when:

- The flavor you touched builds (`:app:assemble<Flavor>Debug`).
- That flavor's bundled `native/config.json` matches the intended Rails origin (`base_url`, start path or tabs, bridge flags).
- iOS still opens `ios/HotwireNativeShell.xcodeproj` on the `HotwireNativeShell` scheme. On a Mac, the `xcodebuild` command in [ios/README.md](ios/README.md) is the build. On Linux, `python3 script/check_contract.py` is the stand-in: it checks the bundle id, the flavor folder reference, and the bridge names. Do not claim `xcodebuild` passed if it did not run.
- No secrets are in git (keystore, `keystore.properties`, `google-services.json`, `.p12`, provisioning profile). The committed itsjustmy target has no push entitlement.
- `cd rails && bundle exec rake test` passes for the Rails gem.
- Links in [README.md](README.md), this file, and `docs/` still point at files that exist.
