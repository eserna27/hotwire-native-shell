# A new client in about an hour

The shell is one Android project. Each client is a flavor plus a JSON document. itsjustmy is the pattern. Nagama and Jazz Controls should follow it. They do not need a fork.

## 0. Questionnaire

`bin/new-app` asks for the values this page used to be filled by hand, then writes them.

```sh
bin/new-app
```

It asks for the display name, slug, bundle id / `applicationId`, production and dev base URLs, brand colors, an icon (image file or favicon URL) and splash background, the start path, cold-start tabs, which bridges are on, and push. When push is yes it requires a `google-services.json` path and turns on the iOS Push Notifications capability (`aps-environment`).

Agents and CI use the same generator without prompts:

```sh
bin/new-app --file flavors/itsjustmy/app.yml --config-only
bin/new-app --file path/to/app.yml
```

Icon rasterizing needs Pillow (`python3-pil`) and, for SVG or a favicon SVG, `rsvg-convert` (`librsvg2-bin`). The script itself needs PyYAML (`python3-yaml`).

`--config-only` prints `native/config.json` and does not write. A full run writes:

- `flavors/<slug>/` (`assets/native/config.json`, `app.yml`, README)
- the Android product flavor, launcher, and splash
- the single iOS target (bundle id, display name, `native` folder, splash icon and color)
- `store/brand.yml` for [store screenshots](STORE_SCREENSHOTS.md)

It finishes by printing the manual steps it cannot do: Xcode signing, uploading an APNs key to the Rails app, and creating the Firebase project. The copied `google-services.json` is gitignored. The skeleton still does not apply the Google services plugin or subscribe to topics.

`bin/new-app --file flavors/itsjustmy/app.yml --config-only` matches [`flavors/itsjustmy/assets/native/config.json`](../flavors/itsjustmy/assets/native/config.json). Applying that file is a separate choice: push is on, so it asks for `google-services.json` and adds the iOS entitlement. The committed pilot target has neither. `python3 script/check_contract.py` still expects that pilot. `python3 script/check_contract.py --flavor <slug>` checks a generated flavor's JSON shape and Gradle wiring.

The sections below are what the command does, and the way to do it by hand.

## 1. Copy the flavor

```sh
cp -R flavors/itsjustmy flavors/nagama
```

Edit `flavors/nagama/assets/native/config.json`:

- `name`: `nagama`
- `base_url`: the Rails origin
- `start_path`, and `tabs` when that app should show a bottom bar before the first page connects the `tabs` bridge
- `bridges`: only the components that app's Hotwire pages send
- `push`: `enabled` and `topics`, or turn push off

`tabs` in the flavor JSON is the cold-start list in [CONTRACT.md](CONTRACT.md). Each item needs an `id`, a `title` (string, plus optional `titles` for `es` / `en`), an `icon` (`home`, `posts`, `search`, `profile`, or `info`), and a `path` or absolute `url`. Add `sf_symbol` or `android_icon` only to override that shared icon. Two usable tabs show the bar before the first page loads. One, or an empty list, keeps a single navigator until then. The shell ignores a bad item and keeps at most five. The live bar is the `tabs` Stimulus controller in [BRIDGES.md](BRIDGES.md), which the shell always registers. A later JSON or markup change does not need a store build. A new Android drawable does.

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

## Splash

The launch screen is that client's favicon on a solid color.

Android uses the AndroidX splash screen (`Theme.SplashScreen` in `android/app/src/main/res/values/themes.xml`), so the same theme works below API 31. `windowSplashScreenAnimatedIcon` is `@drawable/ic_splash`. itsjustmy's drawable layers the launcher background and foreground, which are the site favicon. Copy `android/app/src/itsjustmy/res/drawable/ic_splash.xml` with the launcher assets and replace that artwork. The window color is `@color/splash_background` in `android/app/src/<name>/res/values/colors.xml`. The `main` default is white (`#FFFFFF`). itsjustmy sets the same white there so the flavor file is the override.

`MainActivity` keeps the splash up until the first Hotwire visit renders or that visit fails. If the network never answers, it gives up after 8 seconds.

iOS v1 has one target, so the splash assets live in the asset catalog. `LaunchScreen.storyboard` centers `SplashIcon` on the named color `SplashBackground`. Replace `ios/HotwireNativeShell/Assets.xcassets/SplashIcon.imageset/splash.png` and `SplashBackground.colorset` when you point the target at another client. The system removes that screen when the first frame draws.

Build that client only:

```sh
cd android
./gradlew :app:assembleNagamaDebug
```

## 3. Serve the contract from that Rails app

Install [`hotwire_native_shell-rails`](../rails/README.md) and run `bin/rails generate hotwire_native_shell:install`. The initializer is the config DSL: name, `base_url`, signed-in and signed-out start paths, tabs, bridge flags, and path rules. The gem serves `GET /native/config` and `GET /configurations/android_v1.json` / `ios_v1.json`. Field rules stay in [CONTRACT.md](CONTRACT.md).

The generator copies the Stimulus controllers from [BRIDGES.md](BRIDGES.md) and pins `@hotwired/hotwire-native-bridge`. `menu`, `overflow-menu`, and `tabs` are already registered by the shell. Call `native_tabs` from the layout. Call `native_share`, `native_overflow_menu`, and `native_notification_token` only on the pages that need them. Hide the HTML navbar and drop the title suffix with `native_render_web_nav?` and `native_document_title`. See [NATIVE_UI.md](NATIVE_UI.md).

[rails-example/](../rails-example/README.md) is the curl sketch. It is not the install path.

## 4. Check the offline path

The flavor JSON is inside the APK. Airplane mode on first launch should still open `base_url` + `start_path`. A later successful fetch updates the cached contract on the next cold start.

## iOS

v1 is one Xcode target, `HotwireNativeShell`, not a flavor matrix. The pilot bundle id is `blog.itsjustmy.app`, the same string as the Android `applicationId`. The launcher label on both platforms is `itsjustmy.blog` (`app_name` and `CFBundleDisplayName`). The target bundles [`flavors/itsjustmy/assets/native`](../flavors/itsjustmy/assets/native) so `native/config.json` in the app is that flavor file.

To point the same target at another client:

1. In `ios/HotwireNativeShell.xcodeproj/project.pbxproj`, change `PRODUCT_BUNDLE_IDENTIFIER` and `INFOPLIST_KEY_CFBundleDisplayName`.
2. Point the `native` folder reference at `flavors/<name>/assets/native`.
3. Replace `SplashIcon.imageset/splash.png` with that client's favicon and set `SplashBackground.colorset`. See [Splash](#splash).
4. That client's Rails app must serve `GET /native/config` and `GET /configurations/ios_v1.json`.

Do not add a second JSON contract. `bin/new-app` writes the push entitlement only when the answers turn push on. The itsjustmy pilot target does not have one. Open `ios/HotwireNativeShell.xcodeproj` and run the `HotwireNativeShell` scheme. See [ios/README.md](../ios/README.md).
