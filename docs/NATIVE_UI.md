# Native navigation chrome

Hotwire Native draws the top bar itself: a `UINavigationBar` on iOS and the Hotwire toolbar on Android. The back button and the screen title live there. The Rails app (`eserna27/blogs`) must hide its HTML navbar inside that shell and must set a document title the native bar can show as-is.

This repository registers the native bridge components and records the markup. The Rails helpers that emit it live in [`hotwire_native_shell-rails`](../rails/README.md): `hotwire_native_app?`, `native_render_web_nav?`, `native_document_title`, `native_tabs`, `native_menu`, and `native_overflow_menu`.

## Detect the shell

Use the user agent in the layout. That is available on the first byte, before any script runs.

The shell prefixes the agent with the contract `name` (`itsjustmy;`). Hotwire then appends its own tokens. A request from this app looks like:

```
itsjustmy; Hotwire Native iOS; Turbo Native iOS; bridge-components: [menu overflow-menu tabs notification-token share haptic];
```

Android uses `Hotwire Native Android` and `Turbo Native Android`. Match `Hotwire Native`:

```ruby
def hotwire_native_app?
  request.user_agent.to_s.match?(/Hotwire Native/)
end
helper_method :hotwire_native_app?
```

`itsjustmy` alone is the client id and the site name. It is not proof that the request came from the app.

Two other signals exist after JavaScript runs. They are backups for CSS, not a substitute for the layout check:

- Importing [`@hotwired/hotwire-native-bridge`](https://github.com/hotwired/hotwire-native-bridge) sets `window.HotwireNative` to `{ web }` when that global is absent. A normal browser that loads the same package also gets the global. Bridge controllers stay idle there because the user agent does not list `bridge-components`.
- After the native adapter connects, the document element gains `data-bridge-platform` (`ios` or `android`) and `data-bridge-components` (a space-separated list of registered names).

## Hide the web navbar

The itsjustmy.blog top chrome is the Bootstrap element `nav.navbar` (`navbar navbar-expand-lg`). It holds the brand lockup and the locale switch. When `hotwire_native_app?` is true, omit that element from the layout. The native bar replaces it.

The locale switch is inside that `nav`. Moving it somewhere else, if the app should keep it, is a change in `eserna27/blogs`.

If the navbar is still in the HTML, hide it once the bridge has started:

```css
html[data-bridge-platform] nav.navbar {
  display: none;
}
```

`data-bridge-platform` appears only after the native adapter connects, so the server-side omit is what keeps the HTML navbar from flashing under the native bar.

Other bars on the page (`locale-switch`, the legal footer nav, post headers) are not the top chrome. Leave them unless you have moved their controls.

## Document title

Hotwire copies `document.title` into the native bar when the page finishes rendering. The shell shows that string unchanged.

The site title today is the page name plus a suffix, for example `Un hogar para tus palabras | itsjustmy.blog`. Inside the native app, set the title to the page name only:

```erb
<title>
  <%= hotwire_native_app? ? page_title : "#{page_title} | itsjustmy.blog" %>
</title>
```

A title that still contains `| itsjustmy.blog` is what the native bar will display.

## Menu the site must emit

Register nothing new in `/native/config`. `menu`, `overflow-menu`, and `tabs` are always on, on both platforms, and show up in `bridge-components`. The page opts in by sending the messages below. Until the Rails app emits `menu`, the native top bar is the title and the back button only.

Put both controllers in the Rails app. The full scripts are in [BRIDGES.md](BRIDGES.md). The markup that connects them:

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

`overflow-menu` turns that button into the trailing native ellipsis. A tap replies to `connect`, the web controller clicks the button, and `menu` opens the native sheet (an action sheet on iOS, a bottom sheet on Android). Choosing an item replies with `selectedIndex`, and the controller clicks that `item` target. `index` is the target's position in the list.

`data-bridge-title` is the native label (`Options` on the ellipsis, the item's title in the sheet). `data-bridge-disabled="true"` leaves an item out of the sheet.

Hide the HTML trigger once the component is active:

```css
[data-bridge-components~="overflow-menu"] [data-controller~="bridge--overflow-menu"] {
  display: none;
}
```

`share`, when its flag is on, is a separate bar button beside the ellipsis. The ellipsis stays the trailing item.

## Android system bars

The Android shell targets API 36. Android 16 enforces edge-to-edge and ignores `windowOptOutEdgeToEdgeEnforcement`, so the shell does not opt out. `MainActivity` calls `enableEdgeToEdge()`. `ShellWindowInsets` then pads the activity root by the status bar, the navigation bar, the display cutout, and the keyboard.

That padding is what keeps the Hotwire toolbar, the bottom tabs, and the WebView from drawing under the system bars. The same insets are cleared before they reach those child views, because the toolbar (`fitsSystemWindows` on Hotwire's app bar) and the bottom bar would pad themselves again. The keyboard inset is still delivered: the bottom bar hides while the keyboard is up, and the page stays above it. A modal also hides the bottom bar; the root padding still holds the page above the navigation bar.

Predictive back is enabled (`android:enableOnBackInvokedCallback="true"`). Hotwire pops with `OnBackPressedCallback` when the navigator has a previous entry. At the root screen the system plays the back-to-home animation. The launch screen is the AndroidX splash screen API, installed before `super.onCreate()`.

Rails does not draw those bars. It still hides `nav.navbar` and the HTML tab list, as below, so the page does not stack a second chrome on top of the native one.

## Bottom tabs

The live tab list is the `tabs` bridge, always registered, the same way as `menu`. Rails declares it in the page. The shell renders a Material bottom bar on Android and a tab bar on iOS. There is no `/native/config` flag. The Stimulus controller is in [BRIDGES.md](BRIDGES.md). The field rules, the five-tab cap, and the icon names are in [CONTRACT.md](CONTRACT.md).

`tabs` in `GET /native/config` is the optional list shown before the first page connects. itsjustmy bundles Inicio, Acerca, and Entrar for that cold start. Once a page sends `connect`, that message replaces the list. A message without a `tabs` array leaves the current bar alone.

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

`data-bridge-active="true"` marks the tab a new bar selects. Mark the section that owns the page, including when the nav lives in the layout. Leaving every tab unmarked leaves the current selection in place. `data-bridge-title` is the native label. `data-bridge-id`, `data-bridge-icon`, and `data-bridge-path` match the contract fields. A link's `href` supplies the path when `data-bridge-path` is absent. `data-bridge-url` is the absolute URL for a cross-origin tab. `data-bridge-disabled="true"` omits that link.

Hide the HTML nav once the component is active. In a browser the same links stay on the page.

```css
[data-bridge-components~="tabs"] [data-controller~="bridge--tabs"] {
  display: none;
}
```

With two or more usable tabs, each tab has its own navigator, so a push on Inicio does not change the stack on Posts. Sending the same list again does not rebuild those navigators. Zero or one usable tab leaves the single navigator and draws no bar. An empty array, or an array whose entries are all unusable, does that on purpose. A bad entry is skipped. The shell keeps at most five. Android must keep `main_nav_host` in `navigatorConfigurations()` across recreate, including when the bottom bar is showing and when `tabs: []` returns to the single navigator.

### Login, logout, and a cached config

Rails can rely on this for the auth-first flow:

- **Signed out.** The page sends `tabs: []`. The shell shows one navigator and no bar. Sign-in, registration, password reset, and confirmation are ordinary pushes on that navigator.
- **Login.** When a page sends two or more tabs after that empty list, the shell discards the sign-in navigator and builds one fresh navigator per tab. The tab marked `active` is the one selected. That tab opens at its own path, so Inicio opens `/dashboard`. No sign-in page remains in any back stack. Android starts a new task so the old fragments are not restored. iOS replaces the window root.
- **Logout.** When a page sends `tabs: []` again (the sign-in page after logout), the shell drops every tab navigator and shows one new navigator rooted at that page. Back cannot return to the dashboard. A later page in the signed-out flow that also sends `tabs: []` does not rebuild; it stays on the same navigator.
- **Cached config.** `tabs` in a cached `/native/config` is only the cold start. The first `tabs` connect replaces it, whether that message is `[]` or the signed-in set. The shell does not return to the cached list after that.

On a bar that is already showing, `active` does not switch tabs by itself, and a page that marks no tab `active` does not jump to the first tab. The shell moves only when the page URL belongs to a different tab: it shows that URL on the tab with the longest matching path and pops the copy that landed on the other stack. A tab path of `/` matches every path on that origin, and a longer path such as `/dashboard/posts` wins over `/dashboard`. A page whose path matches no tab, such as a public post, stays on the tab that pushed it. `active` chooses the selected tab when the bar is first built, which is how login lands on Inicio.

A modal is ignored. `/new` and `/edit` stay `context: modal` in path configuration, which includes `/dashboard/posts/new` opened from the overflow menu. A `tabs` message from that screen does not rebuild the bar and does not switch tabs. On Android the bottom bar hides while a modal is up and while the keyboard is up. The visit's `context` is not how you add or remove a tab.

The labels in the markup are whatever the page already rendered. The device language still picks `titles.es` or `titles.en` on the cold-start document, and on a bridge payload that includes `titles`. That choice is separate from the site's `/locale` cookie.

`menu` and `overflow-menu` stay on the top bar of whichever tab is visible. The ellipsis opens that page's action sheet. A page under any tab can send the same `menu` markup. "Nuevo post" is a menu item whose path is modal; it does not go through the tab list.
