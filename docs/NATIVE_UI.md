# Native navigation chrome

Hotwire Native draws the top bar itself: a `UINavigationBar` on iOS and the Hotwire toolbar on Android. The back button and the screen title live there. The Rails app (`eserna27/blogs`) must hide its HTML navbar inside that shell and must set a document title the native bar can show as-is.

This repository registers the native bridge components and records the markup. It does not change the Rails app.

## Detect the shell

Use the user agent in the layout. That is available on the first byte, before any script runs.

The shell prefixes the agent with the contract `name` (`itsjustmy;`). Hotwire then appends its own tokens. A request from this app looks like:

```
itsjustmy; Hotwire Native iOS; Turbo Native iOS; bridge-components: [menu overflow-menu notification-token share haptic];
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

Register nothing new in `/native/config`. `menu` and `overflow-menu` are always on, on both platforms, and show up in `bridge-components`. The page opts in by sending the messages below. Until the Rails app emits them, the native bar is the title and the back button only.

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

## Bottom tabs

Tabs come from `tabs` in `GET /native/config`, not from path configuration and not from `menu`. The shape, the five-tab cap, and the icon names are in [CONTRACT.md](CONTRACT.md).

With two or more usable tabs, Android shows a Material bottom bar (`HotwireBottomNavigationController`) and iOS shows a tab bar (`HotwireTabBarController`). Each tab has its own navigator, so a push on Inicio does not change the stack on Acerca. Reselecting the active Android tab clears that tab back to its start path. Zero or one usable tab leaves the single navigator and draws no bar.

The device language picks `titles.es` or `titles.en`. That is separate from the site's `/locale` cookie, which still switches the HTML. Tab labels update on the next cold start after a new config, not when the user taps ES / EN in the page.

Path configuration still applies inside every tab. `/new` and `/edit` stay modals. A modal does not switch tabs. On Android the bottom bar hides while a modal is up and while the keyboard is up. The visit's `context` is not how you add or remove a tab.

`menu` and `overflow-menu` stay on the top bar of whichever tab is visible. The ellipsis opens that page's action sheet. It is not a tab switcher. A page under any tab can send the same `menu` markup. The tab bar does not add bridge components, and the user agent does not gain a tab token.
