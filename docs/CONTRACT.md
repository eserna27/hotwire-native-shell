# Rails contract

`GET /native/config` tells a Hotwire Native shell which site to open and which bridge components to turn on. Android reads it today. iOS will read the same document later.

This is the shell contract. It is not Hotwire's path configuration. Path configuration is a second JSON file, described at the bottom.

## Request

```
GET /native/config
Accept: application/json
```

No authentication in this skeleton. The response is public app metadata: name, origin, and feature flags. Do not put API keys, signing material, or user data in it.

The Android shell requests `{base_url}/native/config`, where `base_url` comes from the flavor JSON already on the device. The first launch works offline from that file. A successful response is cached and used on the next cold start.

## Response

`Content-Type: application/json`.

itsjustmy, the pilot:

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

The canonical copy is [`flavors/itsjustmy/assets/native/config.json`](../flavors/itsjustmy/assets/native/config.json). The Rails sketch serves that file.

## Fields

| Field | Required | Meaning |
| --- | --- | --- |
| `name` | yes | Short client id. Sent as the Hotwire user-agent prefix (`itsjustmy;`). |
| `base_url` | yes | HTTPS origin of the Rails app, no trailing path. |
| `start_path` | no | Path opened when `tabs` is empty. Default `/`. |
| `tabs` | no | Bottom tabs. Empty array means one navigator and no tab bar. |
| `bridges` | no | Which native bridge components the shell may register. Missing flags are off. |
| `push.enabled` | no | Whether the client wants push. Default `false`. |
| `push.topics` | no | Topic names reserved for a later FCM subscription. Strings only. |

The shell ignores unknown keys. Add fields when you need them. Do not rename or change the type of a field that a shipped app already reads. A breaking change needs a new path (`/native/config/v2`) and a shell release that asks for it.

`base_url` plus a path is the start location. `https://itsjustmy.blog` and `/` open `https://itsjustmy.blog/`.

### Tabs

Each item:

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Stable navigator name. Unique within the document. |
| `title` | yes | Tab label. |
| `path` | yes | Path on `base_url`. |
| `icon` | no | `home` (default), `posts`, `search`, or `profile`. |

Android shows at most four tabs. Further items are ignored. itsjustmy ships with `"tabs": []`.

Example for a later client:

```json
"tabs": [
  { "id": "home", "title": "Home", "path": "/", "icon": "home" },
  { "id": "posts", "title": "Posts", "path": "/posts", "icon": "posts" }
]
```

### Bridges

Boolean flags. The native component name (the Stimulus `static component` value) is not always the same string as the JSON key.

| JSON key | Component name | itsjustmy | Android skeleton |
| --- | --- | --- | --- |
| `notification_token` | `notification-token` | on | placeholder token, no FCM |
| `share` | `share` | on | system share sheet |
| `haptic` | `haptic` | on | haptic feedback |
| `camera` | `camera` | off | not registered |
| `biometric` | `biometric` | off | not registered |
| `clipboard` | `clipboard` | off | not registered |
| `file_download` | `file-download` | off | not registered |

A flag that is `false` or absent is not registered, so it does not show up in the `bridge-components:` user-agent list. The web bridge then leaves the HTML in place. See [BRIDGES.md](BRIDGES.md).

If a reserved flag is `true` and the shell has no component yet, Android logs a warning and still does not register it.

### Push

`push.enabled` and `push.topics` are recorded at startup. This skeleton does not create an FCM token and does not subscribe to topics. `notification-token` replies with the literal `placeholder-not-a-device-token` until a client app adds Firebase. Do not store that string as a device token.

## Path configuration

Hotwire Native loads a different JSON for navigation rules (modals, pull to refresh, native screens). Android asks for:

```
GET /configurations/android_v1.json
```

iOS will ask for `/configurations/ios_v1.json`. The sketch serves the same bundled rules on both URLs until those rules need to differ. Version the filename (`android_v2.json`) when a shell release cannot read the old rules. Leave the old URL up for already-installed apps.

The bundled copy is [`android/app/src/main/assets/json/path-configuration.json`](../android/app/src/main/assets/json/path-configuration.json). Hotwire loads that file first, then a cached remote copy, then a fresh download. A 404 on the remote URL is fine: the app keeps the bundled rules.

```json
{
  "settings": {},
  "rules": [
    {
      "patterns": [".*"],
      "properties": {
        "context": "default",
        "uri": "hotwire://fragment/web",
        "pull_to_refresh_enabled": true
      }
    },
    {
      "patterns": ["/new$", "/edit$"],
      "properties": {
        "context": "modal",
        "uri": "hotwire://fragment/web/modal/sheet",
        "pull_to_refresh_enabled": false
      }
    }
  ]
}
```

`uri` values match the deep links on `HotwireWebFragment` and `HotwireWebBottomSheetFragment` in Hotwire Native Android 1.3.x.
