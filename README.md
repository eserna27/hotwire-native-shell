# Hotwire Native Shell

A reusable [Hotwire Native](https://native.hotwired.dev/) shell for our own Rails apps. The app is a thin Android and iOS container. Rails decides the origin, the start path, and which bridge components are on, through `GET /native/config`.

**itsjustmy.blog** is the pilot. Nagama and Jazz Controls can become flavors of this same project. The library is MIT and free to use. It is not a product we sell.

> Biblioteca libre (MIT) para envolver apps Rails con Hotwire Native. El piloto es itsjustmy.blog, en Android y en iOS, con el mismo contrato JSON. No es un producto comercial.

**Agents:** [AGENTS.md](AGENTS.md) is the playbook for building or extending a client app from this shell.

## What this is

- One Kotlin app on [Hotwire Native Android 1.3.1](https://github.com/hotwired/hotwire-native-android/releases/tag/1.3.1) (`dev.hotwire:core`, `dev.hotwire:navigation-fragments`).
- One Swift app on [Hotwire Native iOS 1.3.1](https://github.com/hotwired/hotwire-native-ios/releases/tag/1.3.1) (`HotwireNative` via Swift Package Manager).
- A stable JSON contract, plus Hotwire's own path-configuration file.
- A flavor per client on Android. iOS v1 is one target that bundles the itsjustmy flavor. Both use bundle id `blog.itsjustmy.app`.
- Native navigation chrome: `menu`, `overflow-menu`, and `tabs` are always registered. Stub bridges for notification token, share, and haptic. Camera, biometric, clipboard, and file download stay off. The Rails rules for hiding the HTML navbar, the title suffix, and the tab markup are in [docs/NATIVE_UI.md](docs/NATIVE_UI.md).

## What this is not

- Not a hosted service, an app store listing, or a paid SDK.
- Not the itsjustmy.blog Rails application. That site stays in its own repo and only needs to serve the contract.
- Not an App Store listing. The iOS project has no signing identity, provisioning profile, or push entitlement in git. See [ios/README.md](ios/README.md).
- Not Firebase and not APNs. Push is a flag and a topic list. The notification bridge returns a placeholder token until a client app adds a real provider. No `google-services.json` and no keystores are in git.

## Layout

```
docs/CONTRACT.md          Rails ↔ native JSON
docs/NEW_APP.md           another client (Nagama, …)
docs/BRIDGES.md           bridge catalog
docs/NATIVE_UI.md         native bar, hidden web navbar, titles
android/                  Hotwire Native Android app
ios/                      Hotwire Native iOS app
flavors/itsjustmy/        sample flavor (bundle id in Gradle and in the Xcode target; JSON lives here)
rails/                    hotwire_native_shell-rails gem (install this in a Rails app)
rails-example/            sketch that serves GET /native/config without Rails
```

## Contract

`GET /native/config` for the pilot:

```json
{
  "name": "itsjustmy",
  "base_url": "https://itsjustmy.blog",
  "start_path": "/",
  "tabs": [
    {
      "id": "home",
      "title": "Inicio",
      "titles": { "es": "Inicio", "en": "Home" },
      "path": "/",
      "icon": "home"
    },
    {
      "id": "about",
      "title": "Acerca",
      "titles": { "es": "Acerca", "en": "About" },
      "path": "/acerca",
      "icon": "info",
      "sf_symbol": "info.circle"
    },
    {
      "id": "sign_in",
      "title": "Entrar",
      "titles": { "es": "Entrar", "en": "Sign in" },
      "path": "/users/sign_in",
      "icon": "profile",
      "android_icon": "ic_tab_profile"
    }
  ],
  "bridges": {
    "notification_token": true,
    "share": true,
    "haptic": true,
    "camera": false,
    "biometric": false,
    "clipboard": false,
    "file_download": false
  },
  "push": {
    "enabled": true,
    "topics": ["posts"]
  }
}
```

Field rules are in [docs/CONTRACT.md](docs/CONTRACT.md). The file above is [`flavors/itsjustmy/assets/native/config.json`](flavors/itsjustmy/assets/native/config.json). Android and iOS both package it for offline launch and refresh it from the server when they can.

`tabs` in that JSON is the cold-start bar, used until the first page connects the always-registered `tabs` bridge. The bridge is how Rails declares the live tabs (id, title, icon, path, and which one is active). Two or more usable entries turn on a native bottom bar, one navigator stack per tab, without a new build. Zero or one keeps the single navigator. The shell keeps at most five and skips a bad entry instead of crashing. `icon` is a shared name (`home`, `posts`, `search`, `profile`, `info`). `sf_symbol` and `android_icon` are optional per-platform overrides. `titles` is an `es` / `en` (or other language) map; a string `title` is the fallback. The three itsjustmy paths above are live public routes. The Stimulus controller and the HTML are in [docs/BRIDGES.md](docs/BRIDGES.md) and [docs/NATIVE_UI.md](docs/NATIVE_UI.md).

Hotwire navigation rules (modal `/new` and `/edit`, pull to refresh) are `GET /configurations/android_v1.json` on Android and `GET /configurations/ios_v1.json` on iOS. They are not part of `/native/config`.

## Android

Open `android/` in Android Studio, or:

```sh
cd android
./gradlew assembleDebug
```

JDK 17 or newer. Details, signing, and the emulator cleartext exception are in [android/README.md](android/README.md).

## iOS

Open `ios/HotwireNativeShell.xcodeproj` in Xcode 15 or newer and run the `HotwireNativeShell` scheme. On a Mac:

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

That command needs Xcode. It does not run on Linux. Details, the simulator cleartext exception, and the missing signing secrets are in [ios/README.md](ios/README.md).

## Rails

Install [`hotwire_native_shell-rails`](rails/README.md) in the Rails app (`rails g hotwire_native_shell:install`). It serves `GET /native/config`, both path-configuration URLs, the bridge helpers, and device-token push. The sketch in [rails-example/](rails-example/README.md) is the same contract without a full Rails app, for a local curl check. Until `https://itsjustmy.blog/native/config` exists, the installed app uses the JSON bundled with it.

## Another client

Copy `flavors/itsjustmy`, add a Gradle flavor, and point that app's Rails at the same routes. iOS v1 is the one Xcode target; swap its bundle id and the bundled flavor folder. Steps are in [docs/NEW_APP.md](docs/NEW_APP.md).

## License

[MIT](LICENSE). Copyright (c) 2026 eserna27.
