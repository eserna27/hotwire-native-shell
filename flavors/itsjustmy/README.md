# itsjustmy

Pilot flavor for [itsjustmy.blog](https://itsjustmy.blog).

| | |
| --- | --- |
| Android `applicationId` and iOS bundle id | `blog.itsjustmy.app` |
| Display name | itsjustmy.blog |
| Contract | [`assets/native/config.json`](assets/native/config.json) |
| Bridges on | `notification-token`, `share`, `haptic` |
| Always registered | `menu`, `overflow-menu` (native bar; see [docs/NATIVE_UI.md](../../docs/NATIVE_UI.md)) |
| Tabs | Inicio `/`, Acerca `/acerca`, Entrar `/users/sign_in` (live public routes; labels follow the device language) |

The Android `itsjustmy` source set packages `assets/` into the APK. The iOS target references `assets/native` as a folder, so the same JSON is the offline copy of `GET /native/config` on both platforms. The launcher icons are the site favicon (`/icon.svg` on itsjustmy.blog).

`push.topics` lists `posts`. Both shells record that. Neither subscribes to Firebase or APNs yet.
