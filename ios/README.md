# iOS

Not in this repository yet.

The iOS app will be a Hotwire Native iOS shell that reads the same `GET /native/config` document as Android. Bridge component names stay `notification-token`, `share`, and `haptic`. Path configuration can start as `GET /configurations/ios_v1.json`, which the Rails sketch already serves with the Android rules.

Do not add an Xcode project, signing certificates, or push entitlements until Android has been exercised against itsjustmy.blog.

See [docs/CONTRACT.md](../docs/CONTRACT.md) and [docs/NEW_APP.md](../docs/NEW_APP.md).
