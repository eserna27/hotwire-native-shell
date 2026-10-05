# itsjustmy

Pilot flavor for [itsjustmy.blog](https://itsjustmy.blog).

| | |
| --- | --- |
| Android `applicationId` and iOS bundle id | `blog.itsjustmy.app` |
| Display name | itsjustmy.blog |
| Contract | [`assets/native/config.json`](assets/native/config.json) |
| Bridges on | `notification-token`, `share`, `haptic` |
| Always registered | `menu`, `overflow-menu`, `tabs` (native chrome; see [docs/NATIVE_UI.md](../../docs/NATIVE_UI.md)) |
| Cold-start tabs | Inicio `/`, Acerca `/acerca`, Entrar `/users/sign_in` (live public routes; the `tabs` bridge replaces this list after the first page connects) |

The Android `itsjustmy` source set packages `assets/` into the APK. The iOS target references `assets/native` as a folder, so the same JSON is the offline copy of `GET /native/config` on both platforms. The launcher icons are the site favicon (`/icon.svg` on itsjustmy.blog). The splash screen uses that same artwork on a white background.

`push.topics` lists `posts`. Both shells record that. Neither subscribes to Firebase or APNs yet.
