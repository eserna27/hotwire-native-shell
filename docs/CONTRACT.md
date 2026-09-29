# Rails contract

`GET /native/config` tells a Hotwire Native shell which site to open and which bridge components to turn on. Android and iOS both read this document.

This is the shell contract. It is not Hotwire's path configuration. Path configuration is a second JSON file, described at the bottom.

## Request

```
GET /native/config
Accept: application/json
```

No authentication in this skeleton. The response is public app metadata: name, origin, and feature flags. Do not put API keys, signing material, or user data in it.

Each shell requests `{base_url}/native/config`, where `base_url` comes from the flavor JSON already on the device. The first launch works offline from that file. A successful response is cached and used on the next cold start. Android stores that cache in app files. iOS stores the raw response under Application Support.

## Response

`Content-Type: application/json`.

itsjustmy, the pilot:

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

The canonical copy is [`flavors/itsjustmy/assets/native/config.json`](../flavors/itsjustmy/assets/native/config.json). The Rails sketch serves that file.

## Fields

| Field | Required | Meaning |
| --- | --- | --- |
| `name` | yes | Short client id. Sent as the Hotwire user-agent prefix (`itsjustmy;`). |
| `base_url` | yes | HTTPS origin of the Rails app, no trailing path. |
| `start_path` | no | Path opened when no usable tab supplies a start location. Default `/`. |
| `tabs` | no | Cold-start bottom tabs, in order, shown until a page connects the `tabs` bridge. Missing, `[]`, or fewer than two usable entries means one navigator and no tab bar. |
| `bridges` | no | Which native bridge components the shell may register. Missing flags are off. |
| `push.enabled` | no | Whether the client wants push. Default `false`. |
| `push.topics` | no | Topic names reserved for a later FCM subscription. Strings only. |

The shell ignores unknown keys. Add fields when you need them. Do not rename or change the type of a field that a shipped app already reads. A breaking change needs a new path (`/native/config/v2`) and a shell release that asks for it.

`base_url` plus a path is the start location. `https://itsjustmy.blog` and `/` open `https://itsjustmy.blog/`.

### Tabs

`tabs` on this document is the cold-start list. The shell shows it before any page has connected the `tabs` bridge. It is not a bridge flag. The page replaces the list by sending `connect` from the Stimulus controller in [BRIDGES.md](BRIDGES.md). The markup is in [NATIVE_UI.md](NATIVE_UI.md). Changing either the document or the markup needs no store build.

Each usable entry becomes its own navigator stack: `HotwireBottomNavigationController` on Android and `HotwireTabBarController` on iOS. The same resolved list, sent again from a later page, only changes which tab is selected. A different list rebuilds those navigators.

Two usable tabs are the minimum that shows a bar. Zero or one keeps the single navigator. A lone usable tab supplies that navigator's start location. With zero, the shell opens `start_path`.

The shell keeps at most five tabs, which is Material's bottom-bar limit and the usual iOS tab bar before a More item. Further usable entries are ignored. An entry that fails the rules below is skipped. A bad entry does not reject the rest of `/native/config`, and it does not crash the app. A `tabs` value that is not an array is treated as no tabs on this document. On the bridge, a missing `tabs` key or a non-array leaves the current bar alone, and a present array is applied even when every entry is skipped.

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Stable id, unique in the list. 1–64 characters: ASCII letters, digits, `.`, `_`, `-`, starting with a letter or digit. The first duplicate is kept. Android uses it as the navigator name. Hotwire Native iOS 1.3.1 uses the visible title as the navigator name and this `id` to find that tab's navigator. |
| `title` | one of `title` / `titles` | Label. A string, or a locale object such as `{ "es": "Inicio", "en": "Home" }`. |
| `titles` | one of `title` / `titles` | Locale object. Keys are language codes (`es`, `en`, or `es-MX`). For a matching language this wins over a string `title`. |
| `path` | one of `path` / `url` | Path joined to `base_url`. Must not contain a scheme or whitespace. |
| `url` | one of `path` / `url` | Absolute `http` or `https` URL. When it is valid it replaces `path`, including on another origin. |
| `icon` | no | Shared catalog name. Default `home`. Unknown names use `home`. |
| `sf_symbol` | no | iOS-only SF Symbol, such as `info.circle`. Used when the system can draw it. Unknown names fall back to `icon`. |
| `android_icon` | no | Android drawable resource name already in the APK, such as `ic_tab_profile`. Unknown names fall back to `icon`. |
| `active` | no | Bridge payload only. `true` or the string `"true"` selects that tab. The first kept tab with this set wins. Config entries omit it, so cold start selects the first tab. |

`title` stays a string in the bundled file so a shell that only decodes a string can still read the tab. A locale object in `title` is accepted by this shell. An older shell that requires a string will refuse the whole remote document and keep its previous copy. Prefer a string `title` plus `titles` when both shells are in the field. `titles`, `url`, `sf_symbol`, and `android_icon` are extra keys. A shell that does not know them ignores them.

The label is chosen from the device language, not from the Rails locale cookie:

1. `titles` (or a locale object in `title`) for the full tag, then the language (`es-MX` then `es`).
2. The string `title`.
3. `en`, then `es`, then any other locale string.
4. No label: the tab is skipped.

Labels are collapsed to one line and cut at 40 characters.

#### Icons

One shared `icon` name is the portable choice. Rails does not have to name a different asset per platform. The shell maps that name:

| `icon` | Android drawable | iOS SF Symbol |
| --- | --- | --- |
| `home` | `ic_tab_home` | `house` |
| `posts` | `ic_tab_posts` | `doc.text` |
| `search` | `ic_tab_search` | `magnifyingglass` |
| `profile` | `ic_tab_profile` | `person` |
| `info` | `ic_tab_info` | `info.circle` |

Anything else, including a missing `icon`, uses `home` / `house`.

`sf_symbol` overrides iOS only. SF Symbols ship with the OS, so a new symbol does not need a shell build. `android_icon` overrides Android only. It has to be a drawable already compiled into the APK (`ic_tab_home`, `ic_tab_posts`, `ic_tab_search`, `ic_tab_profile`, `ic_tab_info`, or another drawable that flavor already ships). A new Android picture still needs a shell release. The shell never downloads an icon.

itsjustmy bundles three tabs for real public routes (`/`, `/acerca`, `/users/sign_in` all returned HTTP 200). `/about` also returns 200; the bundled path is `/acerca` because the site's default locale is Spanish. `/posts` and `/explore` are not routes on the site. `/dashboard` exists and redirects to sign-in when logged out, so it is not a bundled tab.

```json
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
]
```

Path configuration is a separate document. It still decides `context` and pull-to-refresh for every visit, including a tab's start path and later pushes inside that tab. A `modal` rule presents that visit from the tab's navigator. It does not switch tabs. Android's controller hides the bottom bar on modal screens and while the keyboard is up. Tabs are not declared in `/configurations/android_v1.json` or `ios_v1.json`.

`menu` and `overflow-menu` stay registered either way. They add the current page's ellipsis and action sheet to that tab's top bar. The `tabs` component is registered with them and is the live source of the bar after the first `connect`. See [NATIVE_UI.md](NATIVE_UI.md).

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

`menu`, `overflow-menu`, and `tabs` are not flags. Both shells always register them. `menu` and `overflow-menu` host the site's menu on the top bar. `tabs` hosts the bottom bar. The markup is in [NATIVE_UI.md](NATIVE_UI.md).

If a reserved flag is `true` and the shell has no component yet, Android and iOS log a warning and still do not register it. The iOS stubs for the three itsjustmy bridges match the Android ones, including the placeholder notification token.

### Push

`push.enabled` and `push.topics` are recorded at startup. This skeleton does not create a device token and does not subscribe to topics. `notification-token` replies with the literal `placeholder-not-a-device-token` until a client app adds a real provider (FCM on Android). iOS has no APNs entitlement in this skeleton. Do not store that string as a device token.

## Path configuration

Hotwire Native loads a different JSON for navigation rules (modals, pull to refresh, native screens). Android asks for:

```
GET /configurations/android_v1.json
```

iOS asks for:

```
GET /configurations/ios_v1.json
```

The sketch serves the same rules document on both URLs until those rules need to differ. Version the filename (`android_v2.json`, `ios_v2.json`) when a shell release cannot read the old rules. Leave the old URL up for already-installed apps.

Android bundles [`android/app/src/main/assets/json/path-configuration.json`](../android/app/src/main/assets/json/path-configuration.json). iOS bundles [`ios/HotwireNativeShell/path-configuration.json`](../ios/HotwireNativeShell/path-configuration.json). Both files describe the same behavior: every path is the default context with pull to refresh, and `/new` and `/edit` are modals without pull to refresh. The Android file also sets `uri`, which iOS ignores. The iOS file omits `uri`. Hotwire loads the bundled file first, then a cached remote copy, then a fresh download. A 404 on the remote URL is fine: the app keeps the bundled rules.

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

The example above is the Android bundled file. `uri` values match the deep links on `HotwireWebFragment` and `HotwireWebBottomSheetFragment` in Hotwire Native Android 1.3.x. iOS does not read `uri`.
