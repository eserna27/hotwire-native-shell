# Bridge catalog

Bridge components are the Hotwire Native channel between a Stimulus controller and the native shell (Kotlin on Android, Swift on iOS). The web package is [`@hotwired/hotwire-native-bridge`](https://github.com/hotwired/hotwire-native-bridge). Android registers a `BridgeComponentFactory` whose name equals the controller's `static component`. iOS subclasses `BridgeComponent` and overrides `name` with that same string.

`menu` and `overflow-menu` are always registered. They drive the native navigation chrome and are not keys in [`/native/config`](CONTRACT.md). See [NATIVE_UI.md](NATIVE_UI.md). Every other factory is registered only when its flag is `true`. itsjustmy turns on three of those. The rest are named here so a later client can enable them without inventing new JSON keys.

Hide a web control when the native component is active:

```css
[data-bridge-components~="share"] [data-controller~="bridge--share"] {
  display: none;
}
```

Use the component name (`share`, `haptic`, `notification-token`), not the JSON key.

## notification-token

JSON key `notification_token`. Component name `notification-token`.

Asks the shell for a push token. The skeleton replies to `connect` and `get` with:

```json
{ "token": "placeholder-not-a-device-token", "provider": "placeholder" }
```

That value is not an FCM token. `POST_NOTIFICATIONS` is on the manifest so a later change can prompt for it. There is no `google-services.json`, no Firebase dependency, and no topic subscription. `push.topics` (for itsjustmy, `["posts"]`) is only logged.

```javascript
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "notification-token"

  get() {
    this.send("get", {}, (message) => {
      const token = message.data.token
      const provider = message.data.provider
      if (provider === "placeholder") return
      // POST the real token to Rails here.
    })
  }
}
```

```html
<div data-controller="bridge--notification-token">
  <button data-action="bridge--notification-token#get" type="button">Enable notifications</button>
</div>
```

When you add FCM in a client app:

1. Create a Firebase Android app whose id is that flavor's `applicationId` (`blog.itsjustmy.app` for the pilot).
2. Download `google-services.json` into `android/app/` and keep it out of git.
3. Add the Google services plugin and `firebase-messaging` only in that client build.
4. Replace `NotificationTokenComponent` so `provider` is `fcm` and `token` is the FCM registration token.
5. Subscribe to `push.topics` from the config after the token exists.

Until step 4, Rails must ignore `placeholder-not-a-device-token`.

iOS replies with the same JSON. There is no APNs entitlement, no push capability, and no device token in this skeleton. Do not treat `placeholder-not-a-device-token` as an APNs token either.

## share

JSON key `share`. Component name `share`.

`connect` carries `{ "url": "https://..." }`. Android adds a toolbar action that opens `Intent.ACTION_SEND`. iOS adds a navigation-bar button that opens `UIActivityViewController`. If `url` is missing, both use the page URL on the bridge message. `disconnect` removes the action.

```javascript
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "share"

  connect() {
    super.connect()
    this.send("connect", { url: window.location.href })
  }
}
```

```html
<meta data-controller="bridge--share">
```

## haptic

JSON key `haptic`. Component name `haptic`.

`vibrate` carries `{ "feedback": "success" | "warning" | "error" }`. Empty means `success`. On Android 11 and later, `success` uses `CONFIRM` and the other two use `REJECT`. On iOS, `success`, `warning`, and `error` map to `UINotificationFeedbackGenerator` (`.success`, `.warning`, `.error`).

```javascript
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "haptic"

  vibrate() {
    const feedback = this.bridgeElement.bridgeAttribute("feedback") || "success"
    this.send("vibrate", { feedback })
  }
}
```

```html
<button type="button" data-controller="bridge--haptic" data-action="bridge--haptic#vibrate">
  Tap
</button>
```

## menu

Component name `menu`. There is no JSON key. Both platforms always register it.

`display` carries:

```json
{
  "title": "Select an option",
  "items": [{ "title": "Option One", "index": 0 }],
  "source": { "x": 0, "y": 0, "width": 0, "height": 0 }
}
```

`index` is the item's position in the Stimulus `item` target list. iOS presents an action sheet and uses `source` (from `getBoundingClientRect`) to anchor the popover. Android presents a bottom sheet and ignores `source`. The reply is `{ "selectedIndex": 0 }`. Cancel on iOS, and dismissing the sheet on Android, sends no reply.

```javascript
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "menu"
  static targets = ["title", "item"]

  show(event) {
    if (!this.enabled) return
    event.stopImmediatePropagation()
    const title = new BridgeElement(this.titleTarget).title
    const items = this.itemTargets.flatMap((element, index) => {
      const bridgeElement = new BridgeElement(element)
      if (bridgeElement.disabled) return []
      return [{ title: bridgeElement.title, index }]
    })
    const rect = event.target.getBoundingClientRect()
    this.send("display", {
      title,
      items,
      source: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
    }, (message) => {
      new BridgeElement(this.itemTargets[message.data.selectedIndex]).click()
    })
  }
}
```

Ship this file from the Rails app (`eserna27/blogs`). This repository does not.

## overflow-menu

Component name `overflow-menu`. There is no JSON key. Both platforms always register it.

`connect` carries `{ "label": "Options" }`. iOS adds a trailing navigation-bar button (`ellipsis.circle`). Android adds a trailing toolbar action with the same ellipsis. The reply has no data. The web controller clicks the element, which should also run `bridge--menu#show`.

The overflow button is the trailing item. `share`, when that flag is on, sits beside it.

```javascript
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "overflow-menu"

  connect() {
    super.connect()
    this.send("connect", { label: this.bridgeElement.title }, () => {
      this.bridgeElement.click()
    })
  }
}
```

```html
<div data-controller="menu bridge--menu">
  <button type="button"
          data-controller="bridge--overflow-menu"
          data-action="click->bridge--menu#show click->menu#show"
          data-bridge-title="Options">
    Open Menu
  </button>
  <p hidden data-bridge--menu-target="title">Select an option</p>
  <a data-bridge--menu-target="item" href="/edit">Edit</a>
</div>
```

`data-bridge-title` is the native label. Without it, the bridge uses the element's text. Hide the HTML control once the component is active:

```css
[data-bridge-components~="overflow-menu"] [data-controller~="bridge--overflow-menu"] {
  display: none;
}
```

The native navigation bar title is `document.title`. How the Rails layout detects the shell, hides `nav.navbar`, and drops the `| itsjustmy.blog` suffix is in [NATIVE_UI.md](NATIVE_UI.md).

## Reserved, off

These flags exist so flavors can say "not in this app" without a shell change. Setting one to `true` does not register a component yet. Android logs the name and continues.

| JSON key | Intended component | Notes |
| --- | --- | --- |
| `camera` | `camera` | Capture stills. Not implemented. |
| `biometric` | `biometric` | Device credential prompt. Not implemented. |
| `clipboard` | `clipboard` | Read or write the clipboard. Not implemented. |
| `file_download` | `file-download` | Hand a URL to the system download manager. Not implemented. |

Add the Kotlin class and the Swift class, register each from that platform's `BridgeRegistrar` when the flag is on, and document the Stimulus events in this file before flipping a flavor to `true`.
