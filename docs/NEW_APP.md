# A new client in about an hour

The shell is one Android project. Each client is a flavor plus a JSON document. itsjustmy is the pattern. Nagama and Jazz Controls should follow it. They do not need a fork.

## 1. Copy the flavor

```sh
cp -R flavors/itsjustmy flavors/nagama
```

Edit `flavors/nagama/assets/native/config.json`:

- `name`: `nagama`
- `base_url`: the Rails origin
- `start_path`, and `tabs` when that app should open with a bottom bar
- `bridges`: only the components that app's Hotwire pages send
- `push`: `enabled` and `topics`, or turn push off

`tabs` is the ordered list in [CONTRACT.md](CONTRACT.md). Each item needs an `id`, a `title` (string, plus optional `titles` for `es` / `en`), an `icon` (`home`, `posts`, `search`, `profile`, or `info`), and a `path` or absolute `url`. Add `sf_symbol` or `android_icon` only to override that shared icon. Two usable tabs show the bar. One, or an empty list, keeps a single navigator. The shell ignores a bad item and keeps at most five. Those rules are already in the shell, so a later JSON change does not need a store build. A new Android drawable does.

Leave unknown flags `false`.

## 2. Add a Gradle flavor

In `android/app/build.gradle.kts`, next to `itsjustmy`:

```kotlin
create("nagama") {
    dimension = "client"
    applicationId = "app.nagama"
}
```

Point its assets at the new directory:

```kotlin
getByName("nagama") {
    assets.srcDir(rootProject.file("../flavors/nagama/assets"))
}
```

Add `android/app/src/nagama/res/values/strings.xml` with `app_name`, and replace the launcher drawables with that client's icon. Until then, copy the itsjustmy launcher assets and swap the artwork.

Build that client only:

```sh
cd android
./gradlew :app:assembleNagamaDebug
```

## 3. Serve the contract from that Rails app

`GET /native/config` returns the same JSON. `GET /configurations/android_v1.json` returns the Hotwire path rules. Start from [rails-example/](../rails-example/README.md) and [CONTRACT.md](CONTRACT.md).

Install `@hotwired/hotwire-native-bridge` and the Stimulus controllers in [BRIDGES.md](BRIDGES.md) for every bridge you set to `true`. `menu` and `overflow-menu` are already registered. The layout still has to hide the HTML navbar and drop the title suffix. See [NATIVE_UI.md](NATIVE_UI.md).

## 4. Check the offline path

The flavor JSON is inside the APK. Airplane mode on first launch should still open `base_url` + `start_path`. A later successful fetch updates the cached contract on the next cold start.

## iOS

v1 is one Xcode target, `HotwireNativeShell`, not a flavor matrix. The pilot bundle id is `blog.itsjustmy.app`, the same string as the Android `applicationId`. The launcher label on both platforms is `itsjustmy.blog` (`app_name` and `CFBundleDisplayName`). The target bundles [`flavors/itsjustmy/assets/native`](../flavors/itsjustmy/assets/native) so `native/config.json` in the app is that flavor file.

To point the same target at another client:

1. In `ios/HotwireNativeShell.xcodeproj/project.pbxproj`, change `PRODUCT_BUNDLE_IDENTIFIER` and `INFOPLIST_KEY_CFBundleDisplayName`.
2. Point the `native` folder reference at `flavors/<name>/assets/native`.
3. That client's Rails app must serve `GET /native/config` and `GET /configurations/ios_v1.json`.

Do not add a second JSON contract or a push entitlement. Open `ios/HotwireNativeShell.xcodeproj` and run the `HotwireNativeShell` scheme. See [ios/README.md](../ios/README.md).
