# AGENTS.md

> Playbook para agentes: cómo construir o extender una app cliente a partir de este shell Hotwire Native.

This file is the single entry point for coding agents (Cursor cloud agents, Grok Bot, and others). Follow the linked docs. Do not copy them into a second contract.

## What this repo is

A reusable [Hotwire Native](https://native.hotwired.dev/) shell. Android first; iOS later. The native app is a thin container. Rails serves `GET /native/config` and decides the origin, the start path, and which bridge components are on.

MIT licensed, for our own apps (itsjustmy, Nagama, Jazz). It is not a product to sell. Each Rails site stays in its own repository and only needs to serve the contract.

## Do not

- Clone or fork this repo per client. A client is a Gradle flavor plus `flavors/<name>/`.
- Invent a different JSON contract, rename existing fields, or add a second config endpoint. A new key is allowed only when an already-shipped shell can ignore it. Field rules live in [docs/CONTRACT.md](docs/CONTRACT.md).
- Commit secrets: keystores (`*.jks`, `*.keystore`), `keystore.properties`, `google-services.json`, API keys, or signing passwords. Those paths are gitignored.
- Add Firebase Cloud Messaging, the Google services plugin, or `google-services.json` unless the task explicitly asks for FCM on a named client.
- Start an iOS Xcode project, signing certificates, or push entitlements unless the task explicitly asks. [ios/README.md](ios/README.md) is a placeholder.

## Reading order

1. [README.md](README.md) — what the shell is and is not.
2. [docs/CONTRACT.md](docs/CONTRACT.md) — `GET /native/config` and path configuration.
3. [docs/BRIDGES.md](docs/BRIDGES.md) — bridge catalog and the placeholder notification token.
4. [docs/NEW_APP.md](docs/NEW_APP.md) — add a client flavor.
5. [android/README.md](android/README.md) — toolchain, build, signing, emulator cleartext.
6. [rails-example/](rails-example/README.md) — sketch that serves the contract.

Also: [flavors/itsjustmy/README.md](flavors/itsjustmy/README.md), [ios/README.md](ios/README.md), [CONTRIBUTING.md](CONTRIBUTING.md).

## Pilot: itsjustmy

| | |
| --- | --- |
| Flavor | `itsjustmy` in `android/app/build.gradle.kts` (`flavorDimensions` `client`) |
| `applicationId` | `blog.itsjustmy.app` |
| `base_url` | `https://itsjustmy.blog` |
| Flavor directory | `flavors/itsjustmy/` |
| Bundled contract | `flavors/itsjustmy/assets/native/config.json` |
| Launcher name and icon | `android/app/src/itsjustmy/` (`app_name` is **itsjustmy**) |

Open `android/` in Android Studio. JDK 17 or newer.

```sh
cd android
./gradlew :app:assembleItsjustmyDebug
```

Debug APK: `android/app/build/outputs/apk/itsjustmy/debug/app-itsjustmy-debug.apk`.

`./gradlew assembleDebug` builds every flavor. Use the task above when you only need the pilot.

Without the Android SDK, `python3 script/check_contract.py` checks the itsjustmy JSON shape.

## Adding a new app

Follow [docs/NEW_APP.md](docs/NEW_APP.md). Checklist:

1. Copy `flavors/itsjustmy` to `flavors/<name>`.
2. Edit `flavors/<name>/assets/native/config.json`: `name`, `base_url`, `start_path` or `tabs`, `bridges`, and `push`. Leave bridge flags you are not using set to `false`.
3. In `android/app/build.gradle.kts`, next to `itsjustmy`, add a product flavor on dimension `client` with that client's `applicationId`, and set `assets.srcDir` to `../flavors/<name>/assets`.
4. Add `android/app/src/<name>/res/values/strings.xml` with `app_name`, and a launcher icon. Copy the itsjustmy placeholder until a real icon exists.
5. That client's Rails app must serve `GET /native/config` and `GET /configurations/android_v1.json` (and `GET /configurations/ios_v1.json` when an iOS app exists). The JSON must match [docs/CONTRACT.md](docs/CONTRACT.md). Start from [rails-example/](rails-example/README.md).
6. Build that flavor only. Gradle capitalizes the flavor in the task name: `cd android && ./gradlew :app:assembleNagamaDebug` for a flavor named `nagama`.

## Rails contract reminders

- Path configuration is a separate document from `/native/config`. Android requests `GET /configurations/android_v1.json`. The bundled copy is `android/app/src/main/assets/json/path-configuration.json`. A 404 on the remote URL is acceptable; the app keeps the bundled rules.
- The bridge catalog is fixed in the shell and toggled by JSON. Keys: `notification_token`, `share`, `haptic`, `camera`, `biometric`, `clipboard`, `file_download`. The Stimulus component name is not always the JSON key (`notification-token`, `file-download`). See [docs/BRIDGES.md](docs/BRIDGES.md).
- Until FCM is added for that client, `notification-token` replies with `{ "token": "placeholder-not-a-device-token", "provider": "placeholder" }`. Rails must ignore that string. `push.enabled` and `push.topics` are recorded at startup and are not subscribed.

## Success criteria

An agent task on this repo is done when:

- The flavor you touched builds (`:app:assemble<Flavor>Debug`).
- That flavor's bundled `native/config.json` matches the intended Rails origin (`base_url`, start path or tabs, bridge flags).
- No secrets are in git (keystore, `keystore.properties`, `google-services.json`).
- Links in [README.md](README.md), this file, and `docs/` still point at files that exist.
