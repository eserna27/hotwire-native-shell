# itsjustmy

Pilot flavor for [itsjustmy.blog](https://itsjustmy.blog).

| | |
| --- | --- |
| `applicationId` | `blog.itsjustmy.app` |
| Display name | itsjustmy |
| Contract | [`assets/native/config.json`](assets/native/config.json) |
| Bridges on | `notification-token`, `share`, `haptic` |
| Tabs | none (single Hotwire navigator at `/`) |

The Android `itsjustmy` source set packages `assets/` into the APK, so this JSON is the offline copy of `GET /native/config`. The launcher icon under `android/app/src/itsjustmy` is a placeholder monogram.

`push.topics` lists `posts`. The shell records that and does not subscribe to Firebase yet.
