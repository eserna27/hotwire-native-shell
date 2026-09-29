# Contributing

This is a small MIT shell for our own Rails apps. Issues and pull requests are welcome. Keep them focused.

- Do not commit keystores, `keystore.properties`, `google-services.json`, API keys, or signing passwords.
- Contract changes belong in `docs/CONTRACT.md` and `flavors/itsjustmy/assets/native/config.json` together. Add a key only if an old shell can ignore it.
- Bridge behavior belongs in `docs/BRIDGES.md`. Register a component only when its flavor flag is true.
- Android: from `android/`, run `./gradlew assembleDebug` on JDK 17+.
- The JSON shape can be checked without the Android SDK: `python3 script/check_contract.py`.

itsjustmy is the pilot flavor. A new client is a flavor, not a fork. See `docs/NEW_APP.md`.
