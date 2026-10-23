# Bridge catalog

Bridge components are the Hotwire Native channel between a Stimulus controller and the native shell (Kotlin on Android, Swift on iOS). The web package is [`@hotwired/hotwire-native-bridge`](https://github.com/hotwired/hotwire-native-bridge). Android registers a `BridgeComponentFactory` whose name equals the controller's `static component`. iOS subclasses `BridgeComponent` and overrides `name` with that same string.

`menu`, `overflow-menu`, and `tabs` are always registered. They drive the native navigation chrome and are not keys in [`/native/config`](CONTRACT.md). See [NATIVE_UI.md](NATIVE_UI.md). Every other factory is registered only when its flag is `true`. itsjustmy turns on three of those. The rest are named here so a later client can enable them without inventing new JSON keys.

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

The Rails gem ships this controller and POSTs `{ token, provider, platform }` to `POST /native/device_tokens`. It drops `provider: "placeholder"` and the literal `placeholder-not-a-device-token`. See [rails/README.md](../rails/README.md).

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

## tabs

Component name `tabs`. There is no JSON key. Both platforms always register it, the same way as `menu`.

`connect` carries the tab list. The shell draws a Material bottom bar on Android (`HotwireBottomNavigationController`) and a tab bar on iOS (`HotwireTabBarController`). Each usable tab gets its own navigator stack. There is no reply.

```json
{
  "tabs": [
    {
      "id": "home",
      "title": "Inicio",
      "icon": "home",
      "path": "/",
      "active": true
    },
    {
      "id": "about",
      "title": "Acerca",
      "icon": "info",
      "sf_symbol": "info.circle",
      "path": "/acerca",
      "active": false
    }
  ]
}
```

`id`, `title`, `icon`, `path`, `url`, `sf_symbol`, `android_icon`, and `titles` follow the same rules as the cold-start list in [CONTRACT.md](CONTRACT.md). The page is already localized, so this controller sends one `title`. `active` is `true` for the tab that owns the current section. The first kept tab with `active` is the one a new tab bar selects. A later `true` past the five-tab cap is dropped with that tab. A payload that marks no tab `active` does not move the current selection.

A message with no `tabs` key, or a `tabs` value that is not an array, leaves the current bar alone. A present array is applied. Zero or one usable entry removes the bar and leaves the single navigator. `disconnect` does not remove the bar.

Until the first `connect`, the shell shows `tabs` from `/native/config` when that document has two or more usable entries. That array is only the cold-start fallback. A cached document from an older install loses to the first `connect`.

The same resolved list does not rebuild the navigators. Android does not reselect the tab that is already selected, because reselection clears that tab's back stack. A different list replaces them. Android starts a new task, and iOS replaces the window root, so the previous back stacks are gone.

What Rails can rely on:

- Signed out, send `tabs: []`. The shell has one navigator. Sign-in, registration, password reset, and confirmation push on that stack.
- After sign-in, send the signed-in tabs with `active` on Inicio. The shell opens that tab at `/dashboard` and leaves no sign-in page in any stack.
- After sign-out, the sign-in page sends `tabs: []`. The shell drops the tab navigators and roots the new navigator at that sign-in URL. Back cannot return to the dashboard. The next signed-out page can send `tabs: []` again; that does not rebuild.
- On a bar that is already showing, `active` does not switch tabs by itself. A URL that belongs to another tab is shown on the tab with the longest matching path. `/dashboard/posts` wins over `/dashboard`. A tab path of `/` matches the rest of that origin. A page that matches no tab stays where it was pushed. `active` chooses the selected tab when the bar is first built.
- A modal screen (`context: modal`, including `/dashboard/posts/new`) can omit this controller. If the layout still sends `connect`, the shell ignores it and does not switch tabs.

```javascript
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "tabs"
  static targets = ["tab"]

  connect() {
    super.connect()
    const tabs = this.tabTargets.flatMap((element) => {
      const bridgeElement = new BridgeElement(element)
      if (bridgeElement.disabled) return []
      let path = bridgeElement.bridgeAttribute("path") || ""
      if (!path && element.getAttribute("href")) {
        try {
          path = new URL(element.href, window.location.href).pathname
        } catch (e) {
          path = ""
        }
      }
      return [{
        id: bridgeElement.bridgeAttribute("id"),
        title: bridgeElement.title,
        icon: bridgeElement.bridgeAttribute("icon") || "home",
        sf_symbol: bridgeElement.bridgeAttribute("sf-symbol") || "",
        android_icon: bridgeElement.bridgeAttribute("android-icon") || "",
        path,
        url: bridgeElement.bridgeAttribute("url") || "",
        active: bridgeElement.bridgeAttribute("active") === "true"
      }]
    })
    this.send("connect", { tabs })
  }
}
```

```html
<nav data-controller="bridge--tabs">
  <a href="/"
     data-bridge--tabs-target="tab"
     data-bridge-id="home"
     data-bridge-title="Inicio"
     data-bridge-icon="home"
     data-bridge-active="true">Inicio</a>
  <a href="/acerca"
     data-bridge--tabs-target="tab"
     data-bridge-id="about"
     data-bridge-title="Acerca"
     data-bridge-icon="info"
     data-bridge-sf-symbol="info.circle">Acerca</a>
  <a href="/users/sign_in"
     data-bridge--tabs-target="tab"
     data-bridge-id="sign_in"
     data-bridge-title="Entrar"
     data-bridge-icon="profile"
     data-bridge-android-icon="ic_tab_profile">Entrar</a>
</nav>
```

`data-bridge-title` is the native label. Without it, the bridge uses the element's text. `data-bridge-path` wins over the link's `href`. A cross-origin tab needs `data-bridge-url`, because the `href` pathname drops the origin. `data-bridge-disabled="true"` leaves that target out of the message. Hide the HTML nav once the component is active. The links stay usable in a normal browser.

```css
[data-bridge-components~="tabs"] [data-controller~="bridge--tabs"] {
  display: none;
}
```

Ship this file from the Rails app (`eserna27/blogs`). This repository does not. Put the nav in the layout and mark only the current section `data-bridge-active="true"`. An inner page that repeats the same list keeps the stacks. Omit `active` on a page that belongs to no tab. Path configuration still applies inside each tab. `menu` and `overflow-menu` stay on that tab's top bar. A modal path does not change the bar.

## subscription

JSON key `subscription`. Component name `subscription`. itsjustmy leaves the flag off. Turn it on when the host app is ready to sell a store subscription. The shell has no product catalog and no Pro or Stripe logic. The page sends store subscription product ids. iOS buys with StoreKit 2. Android buys with Play Billing Library 9.1.0 (`ProductType.SUBS`).

The buttons stay in the page. They open the store sheet. Do not hide `[data-controller~="bridge--subscription"]`.

Events from the web, and the replies, use the same event name: `purchase`, `restore`, `status`, `finish`. `disconnect` is ignored.

`purchase` needs `product_id` (or the first `product_ids` entry). `restore` and `status` take the same payload and may omit it. An empty product list on `status` or `restore` returns every current subscription. `finish` is how the page tells the shell that the server accepted a transaction.

```json
{
  "product_id": "monthly",
  "product_ids": ["monthly", "yearly"],
  "base_plan_id": "monthly",
  "offer_token": "optional-play-offer-token",
  "account_token": "6F9619FF-8B86-D011-B42D-00CF4FC964FF"
}
```

`base_plan_id` and `offer_token` are Play Billing only. iOS ignores them. When both are omitted, Android uses the first base plan's own offer (the offer with no offer id), not an introductory offer. Pass `base_plan_id` when the Play product has more than one base plan. `offer_token` wins when the page already resolved one.

`account_token` is an opaque id for the signed-in user, not an email. A UUID is attached on both stores (StoreKit `appAccountToken`, Play `obfuscatedAccountId`). Any other string up to 64 characters is attached on Android only.

`finish` uses the same fields plus the transaction the store returned:

```json
{
  "product_id": "monthly",
  "transaction_id": "2000000123456789",
  "purchase_token": "play-purchase-token"
}
```

iOS matches `transaction_id` and calls `Transaction.finish()`. Android matches `purchase_token` (then `transaction_id` as the Play order id, then `product_id`) and calls `acknowledgePurchase`. A purchase that is already finished replies `success`.

Every reply has this shape. A field the store does not set is `null`.

```json
{
  "status": "success",
  "platform": "ios",
  "product_id": "monthly",
  "product_ids": ["monthly", "yearly"],
  "error": null,
  "bundle_id": "blog.example.app",
  "package_name": null,
  "transactions": [
    {
      "product_id": "monthly",
      "transaction_id": "2000000123456789",
      "original_transaction_id": "2000000123456789",
      "purchase_token": null,
      "order_id": null,
      "signed_transaction": "<StoreKit 2 JWS>",
      "original_json": null,
      "signature": null,
      "state": "purchased",
      "expires_at": "2026-11-23T00:00:00Z",
      "acknowledged": false,
      "environment": "sandbox",
      "account_token": "6F9619FF-8B86-D011-B42D-00CF4FC964FF"
    }
  ]
}
```

`status` is `success`, `cancelled`, `pending`, or `error`. `success` means the store answered. It does not by itself mean the user is entitled. Entitlement is a transaction with `state` `purchased`. `cancelled` is the user dismissing the sheet. `pending` is Ask to Buy or a Play pending purchase. `error` is a stable code in `error`:

| `error` | Meaning |
| --- | --- |
| `missing_product_id` | `purchase` had no product id. |
| `invalid_payload` | The message was not the JSON object above. |
| `product_unavailable` | The store has no subscription with that id. |
| `offer_unavailable` | Play had no offer for that product, base plan, or token. |
| `store_unavailable` | Billing or StoreKit is unavailable on this device. |
| `verification_failed` | StoreKit could not verify the transaction on device. |
| `already_owned` | Play already has this subscription. `transactions` still lists it when the query succeeds. |
| `network` | The store could not be reached. |
| `not_found` | `finish` did not find that transaction. |
| `busy` | A Play purchase sheet is already open. |
| `unknown` | Anything else. |

`platform` is `ios` or `android`. `bundle_id` is set on iOS. `package_name` is set on Android (the flavor `applicationId`). Transaction `state` is `purchased`, `pending`, `expired`, or `revoked`.

Verify on the server before granting access, then tell the page to `finish`:

- iOS: `signed_transaction` is the StoreKit 2 JWS (`VerificationResult.jwsRepresentation`). Verify it with Apple's App Store Server library or the App Store Server API. `transaction_id` and `original_transaction_id` identify the subscription. `expires_at` is ISO-8601 when the transaction has an expiration. `environment` is `sandbox`, `production`, or `xcode` on iOS 16 and later.
- Android: `purchase_token` plus `package_name` is what Play Developer API `purchases.subscriptionsv2.get` needs. `order_id` is the Play order id. `original_json` and `signature` are the Play-signed purchase payload. Expiry is not on this payload; the Developer API returns it. `acknowledged` is Play's acknowledgement flag.

`finish` acknowledges the Play purchase and finishes the StoreKit transaction. Do that after the server has granted the entitlement. Until then, `status` returns the same transaction with `acknowledged: false`. Play refunds a purchase that is still unacknowledged after three days. `restore` on iOS calls `AppStore.sync()` and then reads current entitlements. `restore` on Android is the same query as `status` (Play has no separate restore sheet). `status` does not prompt.

```javascript
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "subscription"

  purchase(event) {
    event.preventDefault()
    this.send("purchase", { product_id: "monthly", product_ids: ["monthly"] }, (message) => {
      // message.data.status, message.data.transactions
    })
  }
}
```

```html
<div data-controller="bridge--subscription"
     data-bridge-product-id="monthly"
     data-bridge-product-ids="monthly yearly"
     data-bridge-base-plan-id="monthly"
     data-bridge-account-token="6F9619FF-8B86-D011-B42D-00CF4FC964FF"
     data-bridge-status="true">
  <button type="button" data-action="bridge--subscription#purchase">Subscribe</button>
  <button type="button" data-action="bridge--subscription#restore">Restore purchases</button>
</div>
```

`data-bridge-status="true"` (the default when the attribute is omitted in the gem helper) sends `status` on connect. Set it to `false` to skip that. The gem's controller dispatches `hotwire-native-shell:subscription` with `detail.event` plus the reply. After the server accepts, dispatch `hotwire-native-shell:subscription-finish` on the same element with `detail` set to one transaction, or to `{ transactions: [...] }`. The Rails helpers are `native_subscription`, `hotwire_native_ios?`, and `hotwire_native_android?`. See [rails/README.md](../rails/README.md).

## Reserved, off

These flags exist so flavors can say "not in this app" without a shell change. Setting one to `true` does not register a component yet. Android logs the name and continues.

| JSON key | Intended component | Notes |
| --- | --- | --- |
| `camera` | `camera` | Capture stills. Not implemented. |
| `biometric` | `biometric` | Device credential prompt. Not implemented. |
| `clipboard` | `clipboard` | Read or write the clipboard. Not implemented. |
| `file_download` | `file-download` | Hand a URL to the system download manager. Not implemented. |

Add the Kotlin class and the Swift class, register each from that platform's `BridgeRegistrar` when the flag is on, and document the Stimulus events in this file before flipping a flavor to `true`.
