# Android shell

Hotwire Native Android app. Open the `android/` directory in Android Studio (Empty Views Activity is already done; this folder is the project).

Pinned to [Hotwire Native Android 1.3.1](https://github.com/hotwired/hotwire-native-android/releases/tag/1.3.1) (`dev.hotwire:core` and `dev.hotwire:navigation-fragments`). Toolchain matches that project's demo: Android Gradle Plugin 8.13.2, Kotlin 2.3.0, Gradle 9.2.0, `minSdk` 28, `compileSdk` 35. JDK 17 or newer.

## Build

```sh
cd android
./gradlew assembleDebug
```

The pilot flavor is `itsjustmy`:

```sh
./gradlew :app:assembleItsjustmyDebug
```

The debug APK is `app/build/outputs/apk/itsjustmy/debug/app-itsjustmy-debug.apk`.

`applicationId` is `blog.itsjustmy.app`. The launcher name is **itsjustmy**. The icon under `app/src/itsjustmy` is the [itsjustmy.blog favicon](https://itsjustmy.blog/icon.svg).

Android Studio writes `local.properties` with your SDK path. That file is gitignored.

## What it does

1. `ShellApplication` reads `native/config.json` from the flavor assets (packaged from `flavors/itsjustmy/assets`).
2. It registers `notification-token`, `share`, and `haptic` because that file turns them on.
3. It loads Hotwire path configuration from `assets/json/path-configuration.json`, then tries `{base_url}/configurations/android_v1.json`.
4. `MainActivity` opens `base_url` + `start_path` in a `NavigatorHost`. itsjustmy has no tabs, so there is no bottom bar.
5. A background request stores `GET /native/config`. The cache is used on the next cold start. If the site does not serve the route yet, the bundled JSON stays in effect.

WebView debugging and Hotwire logs are on in debug builds only.

## Secrets

This tree has no keystore, no `google-services.json`, and no API keys.

Release signing is off unless you add it locally:

```sh
cp keystore.properties.example keystore.properties
```

Fill in `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. `keystore.properties` and `*.jks` / `*.keystore` are gitignored. Debug builds use the Android debug keystore.

Firebase Cloud Messaging is not a dependency. See [docs/BRIDGES.md](../docs/BRIDGES.md) before you add a `google-services.json`. Never commit that file.

## Local Rails sketch

Debug builds allow cleartext to `localhost`, `127.0.0.1`, and `10.0.2.2`. Point `base_url` at `http://10.0.2.2:9292` to hit `rails-example` from the emulator. Put the production origin back before you ship. Release builds keep `usesCleartextTraffic` off.

The iOS shell is in [ios/README.md](../ios/README.md). It reads the same flavor JSON. The simulator uses `http://localhost:9292`, not `10.0.2.2`.
