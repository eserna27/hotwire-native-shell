# Hotwire Native Shell

A reusable [Hotwire Native](https://native.hotwired.dev/) shell for our own Rails apps. The app is a thin Android (and, later, iOS) container. Rails decides the origin, the start path, and which bridge components are on, through `GET /native/config`.

**itsjustmy.blog** is the pilot, Android first. Nagama and Jazz Controls can become flavors of this same project. The library is MIT and free to use. It is not a product we sell.

> Biblioteca libre (MIT) para envolver apps Rails con Hotwire Native. El piloto es itsjustmy.blog en Android; iOS usará el mismo contrato JSON. No es un producto comercial.

**Agents:** [AGENTS.md](AGENTS.md) is the playbook for building or extending a client app from this shell.

## What this is

- One Kotlin app on [Hotwire Native Android 1.3.1](https://github.com/hotwired/hotwire-native-android/releases/tag/1.3.1) (`dev.hotwire:core`, `dev.hotwire:navigation-fragments`).
- A stable JSON contract, plus Hotwire's own path-configuration file.
- A flavor per client. itsjustmy uses `applicationId` `blog.itsjustmy.app`.
- Stub bridges for notification token, share, and haptic. Camera, biometric, clipboard, and file download stay off.

## What this is not

- Not a hosted service, an app store listing, or a paid SDK.
- Not the itsjustmy.blog Rails application. That site stays in its own repo and only needs to serve the contract.
- Not an iOS app yet. [ios/README.md](ios/README.md) is a placeholder. The contract is what iOS will share.
- Not Firebase. Push is a flag and a topic list. The notification bridge returns a placeholder token until a client app adds FCM. No `google-services.json` and no keystores are in git.

## Layout

```
docs/CONTRACT.md          Rails ↔ native JSON
docs/NEW_APP.md           another client (Nagama, …)
docs/BRIDGES.md           bridge catalog
android/                  Hotwire Native Android app
flavors/itsjustmy/        sample flavor (bundle id lives in Gradle; JSON lives here)
rails-example/            sketch that serves GET /native/config
ios/README.md             coming next
```

## Contract

`GET /native/config` for the pilot:

```json
{
  "name": "itsjustmy",
  "base_url": "https://itsjustmy.blog",
  "start_path": "/",
  "tabs": [],
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

Field rules, tabs, and the separate path-configuration URL are in [docs/CONTRACT.md](docs/CONTRACT.md). The file above is [`flavors/itsjustmy/assets/native/config.json`](flavors/itsjustmy/assets/native/config.json). Android packages it for offline launch and refreshes it from the server when it can.

Hotwire navigation rules (modal `/new` and `/edit`, pull to refresh) are `GET /configurations/android_v1.json`, not part of `/native/config`.

## Android

Open `android/` in Android Studio, or:

```sh
cd android
./gradlew assembleDebug
```

JDK 17 or newer. Details, signing, and the emulator cleartext exception are in [android/README.md](android/README.md).

## Rails

The sketch in [rails-example/](rails-example/README.md) serves the flavor JSON. Copy the controller and the two routes into the real app when you are ready. Until `https://itsjustmy.blog/native/config` exists, the installed app uses the JSON in the APK.

## Another client

Copy `flavors/itsjustmy`, add a Gradle flavor, point that app's Rails at the same routes. Steps are in [docs/NEW_APP.md](docs/NEW_APP.md).

## License

[MIT](LICENSE). Copyright (c) 2026 eserna27.
