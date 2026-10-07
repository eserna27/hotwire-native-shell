# Contributing

This is a small MIT shell for our own Rails apps. Issues and pull requests are welcome. Keep them focused.

- Do not commit keystores, `keystore.properties`, `google-services.json`, API keys, signing passwords, `.p12` files, or provisioning profiles.
- Contract changes belong in `docs/CONTRACT.md` and `flavors/itsjustmy/assets/native/config.json` together. Add a key only if an old shell can ignore it.
- Bridge behavior belongs in `docs/BRIDGES.md`. Register a component only when its flavor flag is true, on Android and iOS. `menu` and `overflow-menu` are the exception: both platforms always register them. The Rails navbar and title rules live in `docs/NATIVE_UI.md`.
- Android: from `android/`, run `./gradlew assembleDebug` on JDK 17+.
- iOS: open `ios/HotwireNativeShell.xcodeproj` and run the `HotwireNativeShell` scheme. The `xcodebuild` line is in `ios/README.md`. It needs a Mac.
- The JSON shape, and the iOS wiring to it, can be checked without the Android SDK or Xcode: `python3 script/check_contract.py`.
- The Rails gem: `cd rails && bundle exec rake test`.

itsjustmy is the pilot flavor. A new client is a flavor, not a fork. See `docs/NEW_APP.md`.
