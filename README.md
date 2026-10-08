# Hotwire Native Shell

A reusable [Hotwire Native](https://native.hotwired.dev/) shell for our own Rails apps. The app is a thin Android and iOS container. Rails decides the origin, the start path, and which bridge components are on, through `GET /native/config`.

**itsjustmy.blog** is the pilot. Nagama and Jazz Controls can become flavors of this same project. The library is MIT and free to use. It is not a product we sell.

> Biblioteca libre (MIT) para envolver apps Rails con Hotwire Native. El piloto es itsjustmy.blog, en Android y en iOS, con el mismo contrato JSON. No es un producto comercial.

**Agents:** [AGENTS.md](AGENTS.md) is the playbook for building or extending a client app from this shell.

## What this is

- One Kotlin app on [Hotwire Native Android 1.3.1](https://github.com/hotwired/hotwire-native-android/releases/tag/1.3.1) (`dev.hotwire:core`, `dev.hotwire:navigation-fragments`).
- One Swift app on [Hotwire Native iOS 1.3.1](https://github.com/hotwired/hotwire-native-ios/releases/tag/1.3.1) (`HotwireNative` via Swift Package Manager).
- A stable JSON contract, plus Hotwire's own path-configuration file.
- A flavor per client on Android. iOS v1 is one target that bundles the itsjustmy flavor. Both use bundle id `blog.itsjustmy.app`.
- Native navigation chrome: `menu`, `overflow-menu`, and `tabs` are always registered. Stub bridges for notification token, share, and haptic. Camera, biometric, clipboard, and file download stay off. The Rails rules for hiding the HTML navbar, the title suffix, and the tab markup are in [docs/NATIVE_UI.md](docs/NATIVE_UI.md).

## What this is not

- Not a hosted service, an app store listing, or a paid SDK.
- Not the itsjustmy.blog Rails application. That site stays in its own repo and only needs to serve the contract.
- Not an App Store listing. The iOS project has no signing identity, provisioning profile, or push entitlement in git. See [ios/README.md](ios/README.md).
- Not Firebase and not APNs. Push is a flag and a topic list. The notification bridge returns a placeholder token until a client app adds a real provider. No `google-services.json` and no keystores are in git.

## Layout

```
docs/CONTRACT.md          Rails ↔ native JSON
docs/NEW_APP.md           another client (Nagama, …)
docs/BRIDGES.md           bridge catalog
docs/NATIVE_UI.md         native bar, hidden web navbar, titles
docs/STORE_SCREENSHOTS.md App Store and Play posters
bin/new-app               questionnaire that writes a flavor
android/                  Hotwire Native Android app
ios/                      Hotwire Native iOS app
flavors/itsjustmy/        sample flavor (bundle id in Gradle and in the Xcode target; JSON lives here)
rails/                    hotwire_native_shell-rails gem (install this in a Rails app)
rails-example/            sketch that serves GET /native/config without Rails
store/brand.yml           itsjustmy copy and colors for the screenshot toolkit
tools/store-screenshots/  generic Portada renderer, frames, and capture scripts
```

## Contract

`GET /native/config` for the pilot:

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

Field rules are in [docs/CONTRACT.md](docs/CONTRACT.md). The file above is [`flavors/itsjustmy/assets/native/config.json`](flavors/itsjustmy/assets/native/config.json). Android and iOS both package it for offline launch and refresh it from the server when they can.

`tabs` in that JSON is the cold-start bar, used until the first page connects the always-registered `tabs` bridge. The bridge is how Rails declares the live tabs (id, title, icon, path, and which one is active). Two or more usable entries turn on a native bottom bar, one navigator stack per tab, without a new build. Zero or one keeps the single navigator. The shell keeps at most five and skips a bad entry instead of crashing. `icon` is a shared name (`home`, `posts`, `search`, `profile`, `info`). `sf_symbol` and `android_icon` are optional per-platform overrides. `titles` is an `es` / `en` (or other language) map; a string `title` is the fallback. The three itsjustmy paths above are live public routes. The Stimulus controller and the HTML are in [docs/BRIDGES.md](docs/BRIDGES.md) and [docs/NATIVE_UI.md](docs/NATIVE_UI.md).

Hotwire navigation rules (modal `/new` and `/edit`, pull to refresh) are `GET /configurations/android_v1.json` on Android and `GET /configurations/ios_v1.json` on iOS. They are not part of `/native/config`.

## Android

Open `android/` in Android Studio, or:

```sh
cd android
./gradlew assembleDebug
```

JDK 17 or newer. The Android app compiles and targets API 36 (Android 16); `minSdk` stays 28. New flavors inherit that target. Details, signing, edge-to-edge insets, and the emulator cleartext exception are in [android/README.md](android/README.md).

## iOS

Open `ios/HotwireNativeShell.xcodeproj` in Xcode 15 or newer and run the `HotwireNativeShell` scheme. On a Mac:

```sh
cd ios
xcodebuild \
  -project HotwireNativeShell.xcodeproj \
  -scheme HotwireNativeShell \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

That command needs Xcode. It does not run on Linux. Details, the simulator cleartext exception, and the missing signing secrets are in [ios/README.md](ios/README.md).

## Using the Rails gem

[`hotwire_native_shell-rails`](rails/README.md) is the Rails side of this shell. It lives in [`rails/`](rails/) of this repository and is not published to RubyGems. A Rails app that installs it serves `GET /native/config`, both path-configuration URLs, the bridge helpers, and device-token push. The sketch in [rails-example/](rails-example/README.md) is the same contract without a full Rails app, for a local curl check. Until `https://itsjustmy.blog/native/config` exists, the installed shell uses the JSON bundled with it. Field-by-field details stay in [rails/README.md](rails/README.md).

In the Rails app's `Gemfile`, point Bundler at this repo. The gemspec is `rails/hotwire_native_shell-rails.gemspec`, so the glob is required:

```ruby
gem "hotwire_native_shell-rails", github: "eserna27/hotwire-native-shell", glob: "rails/*.gemspec"
```

While developing against a local checkout of this repo, use a path instead:

```ruby
gem "hotwire_native_shell-rails", path: "../hotwire-native-shell/rails"
```

Then:

```sh
bundle install
bin/rails generate hotwire_native_shell:install
bin/rails db:migrate
```

The generator writes the initializer, the routes, the Stimulus bridge controllers, a tabs partial, and the `hotwire_native_shell_device_tokens` migration.

`config/initializers/hotwire_native_shell.rb` is the config. Cold start cannot see a session, so `GET /native/config` publishes the signed-out start path and the signed-out tabs. Signed-in tabs arrive later from the page.

```ruby
HotwireNativeShell.configure do |config|
  config.name = "itsjustmy"
  config.base_url = "https://itsjustmy.blog"
  config.title_suffix = "itsjustmy.blog"
  config.signed_out_start_path = "/users/sign_in"
  config.signed_in_start_path = "/dashboard"

  config.tab :home, auth: :signed_in, title: "Inicio",
    titles: { es: "Inicio", en: "Home" }, path: "/dashboard", icon: "home"
  config.tab :posts, auth: :signed_in, title: "Posts",
    path: "/dashboard/posts", icon: "posts"
  # auth: :signed_out tabs are also the cold-start list. auth: :both copies a tab into both.

  config.menu_item "Sign out", "/users/sign_out", method: :delete, auth: :signed_in
end
```

In the layout, render tabs on every native page, including an empty list (an omitted list leaves the previous bar up), and hide the website navbar inside the app:

```erb
<%= stylesheet_link_tag "hotwire_native_shell" %>
<%= render "shared/native_tabs" %>
<% if native_render_web_nav? %>
  <nav class="navbar"><%# the site's HTML navbar %></nav>
<% end %>
<title><%= native_document_title(page_title) %></title>
```

`native_share` and `native_menu` stay on the pages that need them. Do not add those bridges in the layout.

```erb
<%# posts/show %>
<%= native_share(url: post_url(@post), title: @post.title) %>

<%# a page that should show the native menu %>
<%= native_menu %>
```

Helpers emit nothing unless the user agent contains `Hotwire Native`, so the website is unchanged.

Include the concern so a signed-out native visit goes to the sign-in path, and a signed-in visit to `/` goes to the signed-in start path. The website is not redirected.

```ruby
class ApplicationController < ActionController::Base
  include HotwireNativeShell::NativeEntry
end
```

Push credentials are never committed. Put them in Rails credentials under `hotwire_native_shell`, or in `HOTWIRE_NATIVE_SHELL_*` env vars (env wins when set). APNs token auth needs the `.p8` private key, Key ID, Team ID, and the app's bundle id. FCM HTTP v1 needs the service-account JSON and the project id. `google-services.json` stays on the Android build. It is not the server credential. The full key list is in [rails/README.md](rails/README.md#what-to-upload).

```yaml
hotwire_native_shell:
  apns:
    key_id: "ABC123DEFG"
    team_id: "TEAMID1234"
    bundle_id: "blog.itsjustmy.app"
    private_key: |   # contents of AuthKey_ABC123DEFG.p8
      -----BEGIN PRIVATE KEY-----
      ...
      -----END PRIVATE KEY-----
  fcm:
    project_id: "itsjustmy"
    service_account_json: |   # the Firebase service account file
      { "type": "service_account", "project_id": "itsjustmy", "private_key": "...", "client_email": "..." }
```

App Store reminders, optional until you ship:

- Guideline 4.8. `native_oauth_allowed?` is false inside the app until `config.sign_in_with_apple = true`. Wrap Google, GitHub, and similar buttons in that helper so the website still shows them.
- Guideline 5.1.1(v). Set `config.account_deletion_path` to a route you own, then call `native_account_deletion_link`. The helper renders nothing until that path is set. The gem does not delete accounts.

## Another client

`bin/new-app` asks for the display name, bundle id, origins, colors, icon, tabs, bridges, and push, then writes the flavor, the Gradle source set, the iOS target, and `store/brand.yml`. The same answers can live in an `app.yml` file (`bin/new-app --file app.yml`). Steps done by hand, and the checklist the command prints, are in [docs/NEW_APP.md](docs/NEW_APP.md).

App Store and Play posters are rendered from [store/brand.yml](store/brand.yml) by [tools/store-screenshots/](tools/store-screenshots/). The itsjustmy file is the Portada set (Spanish and English). See [docs/STORE_SCREENSHOTS.md](docs/STORE_SCREENSHOTS.md).

## License

[MIT](LICENSE). Copyright (c) 2026 eserna27.
