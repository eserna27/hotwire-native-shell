# hotwire_native_shell-rails

Rails side of the [Hotwire Native shell](../README.md) in this repo. One gem serves `GET /native/config`, the path-configuration documents, the bridge markup, and device-token push. The shell contract stays in [docs/CONTRACT.md](../docs/CONTRACT.md), [docs/BRIDGES.md](../docs/BRIDGES.md), and [docs/NATIVE_UI.md](../docs/NATIVE_UI.md).

MIT. The [rails-example/](../rails-example/README.md) sketch is still the no-Rails curl demo. A real app uses this gem.

## Install

Add the gem (path, until it is published):

```ruby
gem "hotwire_native_shell-rails", path: "../hotwire-native-shell/rails"
```

Then:

```sh
bin/rails generate hotwire_native_shell:install
bin/rails db:migrate
```

The generator writes:

- `config/initializers/hotwire_native_shell.rb` — the config DSL
- `hotwire_native_shell` in `config/routes.rb`
- Stimulus controllers under `app/javascript/controllers/bridge/`
- `app/views/shared/_native_tabs.html.erb`
- a migration for `hotwire_native_shell_device_tokens`
- an importmap pin, or a `package.json` dependency, for `@hotwired/hotwire-native-bridge` 1.2.2

Importmap apps are pinned. jsbundling / esbuild apps get the dependency entry; run `npm install` or `yarn` so the controllers can import it. Both styles load the copied controllers through the usual Stimulus `controllers/` tree (`bridge/tabs_controller.js` registers as `bridge--tabs`).

In the layout:

```erb
<%= stylesheet_link_tag "hotwire_native_shell" %>
<%= render "shared/native_tabs" %>
<% if native_render_web_nav? %>
  <nav class="navbar"><%# the site's HTML navbar %></nav>
<% end %>
<title><%= native_document_title(page_title) %></title>
```

`native_tabs` is the one bridge that belongs on every native page, including an empty list. Omitting it leaves the previous tab bar up. Share, menu, haptic, and notification-token stay on the pages that use them. The helpers emit nothing unless the user agent contains `Hotwire Native`, so the website is unchanged.

## Config DSL

```ruby
HotwireNativeShell.configure do |config|
  config.name = "itsjustmy"                       # user-agent prefix
  config.base_url = "https://itsjustmy.blog"      # or ->(request) { ... }
  config.title_suffix = "itsjustmy.blog"

  # Cold start cannot see the session. These two are what GET /native/config publishes.
  config.signed_out_start_path = "/users/sign_in"
  config.signed_in_start_path = "/dashboard"

  config.bridges = {
    notification_token: true,
    share: true,
    haptic: true,
    camera: false,
    biometric: false,
    clipboard: false,
    file_download: false
  }
  config.push_enabled = true
  config.push_topics = [ "posts" ]

  # auth: :signed_out is also the cold-start tab list.
  # auth: :signed_in is the page bridge only.
  # auth: :both copies the tab into both.
  config.tab :home, auth: :signed_in, title: "Inicio",
    titles: { es: "Inicio", en: "Home" }, path: "/dashboard", icon: "home"
  config.tab :posts, auth: :signed_in, title: "Posts",
    path: "/dashboard/posts", icon: "posts"

  config.menu_item "Sign out", "/users/sign_out", method: :delete, auth: :signed_in

  config.sign_in_with_apple = false
  config.account_deletion_path = nil
end
```

`GET /native/config` returns `name`, `base_url`, `start_path` (the signed-out path), `tabs` (the signed-out tabs, often `[]`), `bridges`, and `push`. Unknown shell keys are ignored. Bridge flags you leave out are sent as `false`.

Tab fields match the shell: `id`, `title`, optional `titles`, `path` or `url`, `icon` (`home`, `posts`, `search`, `profile`, `info`), optional `sf_symbol`, optional `android_icon`. At most five. A bad id raises when you declare it.

Default path rules match the files bundled in the shell: every path is the default context with pull to refresh, and `/new$` and `/edit$` are modal sheets without it. Android gets `uri`. iOS does not. Replace them with `config.path_rule`.

```ruby
config.path_rule [ "/posts/new$" ], context: "modal", pull_to_refresh: false
```

Calling `path_rule` drops the defaults. Declare every rule you still want.

## Helpers

| Helper | Markup |
| --- | --- |
| `native_tabs` | `<nav data-controller="bridge--tabs">` and one `<a data-bridge--tabs-target="tab">` per tab. Empty when signed out if that list is empty. |
| `native_overflow_menu` / `native_menu` | The combined `menu` + `bridge--menu` + `bridge--overflow-menu` block from [NATIVE_UI.md](../docs/NATIVE_UI.md). Same HTML either way. Items come from the DSL, or pass `items:`. Nothing when the list is empty. |
| `native_share(url:, title:)` | `<meta data-controller="bridge--share" data-bridge-url data-bridge-title>`. |
| `native_notification_token` | Hidden `bridge--notification-token` element. On connect it asks the shell and POSTs a real token. |
| `native_haptic(feedback:)` | Button with `bridge--haptic#vibrate`. |
| `hotwire_native_app?` | User agent matches `Hotwire Native`. `Turbo Native` alone does not. The client id alone does not. |
| `native_render_web_nav?` | True in a browser. Use it to omit `nav.navbar`. |
| `native_document_title(title)` | Strips a trailing ` \| title_suffix` inside the app. |
| `native_signed_out_flow?` / `native_start_path` | Auth-state helpers for the native request. |
| `native_oauth_allowed?` | False in the app until `config.sign_in_with_apple` is true. |
| `native_account_deletion_link` | Link, native only, and only after `account_deletion_path` is set. |

`active` on a tab defaults to the longest matching path. A path of `/` matches the rest of that origin and loses to a longer path. A tab whose `url` is another host does not match this host. Pass `active: ->(request) { ... }` to take over; if any tab has a proc, only procs count, so a page can leave every tab unmarked.

The share sheet in this shell reads `url` only (`ShareComponent` on Android and iOS). `title` is still sent. Hotwire's JSON decoder ignores unknown keys, so the current shell keeps working.

## Auth-first flow

```ruby
class ApplicationController < ActionController::Base
  include HotwireNativeShell::NativeEntry
end
```

On a Hotwire Native HTML GET:

- signed out, and the path is not allowed → redirect to `signed_out_start_path`
- signed in, and the path is `/` → redirect to `signed_in_start_path`

Allowed signed-out requests: the start path itself, `config.signed_out_allowed_paths`, `config.signed_out_allowed_controllers`, a Devise controller, and this gem's controllers. JSON is not redirected. The website is not redirected.

`config.signed_in` defaults to `user_signed_in?` when that method exists.

## Device tokens

The shell's `notification-token` component does not POST. It replies to `get` and `connect` with:

```json
{ "token": "placeholder-not-a-device-token", "provider": "placeholder" }
```

The Stimulus controller in this gem ignores that pair. When the provider is real it POSTs:

```json
{ "token": "<device token>", "provider": "fcm", "platform": "android" }
```

`platform` is `document.documentElement.dataset.bridgePlatform` (`ios` or `android`). The endpoint is `POST /native/device_tokens`. `DELETE /native/device_tokens` with the same `token` removes it. A token that already has an owner can only be deleted by that owner.

```ruby
HotwireNativeShell.config.owner = -> { current_user if user_signed_in? }
```

The default owner reads `request.env["warden"].user`, which is Devise. The device-token controller is `ActionController::Base`, so it does not run your `ApplicationController` filters. Point `owner` at Warden or at a proc that can see the session.

Placeholder rows are not stored.

## Push

`HotwireNativeShell::Push.deliver` sends through APNs (token auth, `.p8`) or FCM HTTP v1. `deliver_to_owner` fans out to that owner's rows. `deliver_topic` is FCM only.

The shell records `push.topics` and does not subscribe. Topic delivery works after a real FCM client subscribes. Do not store `placeholder-not-a-device-token`.

APNs `410` / `404` and FCM `UNREGISTERED` delete the row.

### What to upload

Do not commit the `.p8` or the service-account JSON. The generator adds `AuthKey_*.p8` and `*-firebase-adminsdk-*.json` to `.gitignore`. This repo already ignores `google-services.json` and `*.p12`.

Rails credentials (`bin/rails credentials:edit`):

```yaml
hotwire_native_shell:
  apns:
    key_id: "ABC123DEFG"       # Apple Key ID
    team_id: "TEAMID1234"      # Apple Developer Team ID
    bundle_id: "blog.itsjustmy.app"
    sandbox: false
    private_key: |             # contents of AuthKey_ABC123DEFG.p8
      -----BEGIN PRIVATE KEY-----
      ...
      -----END PRIVATE KEY-----
  fcm:
    project_id: "itsjustmy"
    service_account_json: |    # Firebase service account JSON, the whole file
      { "type": "service_account", "project_id": "itsjustmy", "private_key": "...", "client_email": "..." }
```

ENV overrides credentials when set:

| ENV | Credential |
| --- | --- |
| `HOTWIRE_NATIVE_SHELL_APNS_KEY_ID` | `apns.key_id` |
| `HOTWIRE_NATIVE_SHELL_APNS_TEAM_ID` | `apns.team_id` |
| `HOTWIRE_NATIVE_SHELL_APNS_BUNDLE_ID` | `apns.bundle_id` |
| `HOTWIRE_NATIVE_SHELL_APNS_KEY` | `apns.private_key` (PEM text) |
| `HOTWIRE_NATIVE_SHELL_APNS_KEY_PATH` | path to the `.p8` |
| `HOTWIRE_NATIVE_SHELL_APNS_SANDBOX` | `apns.sandbox` (`true` uses `api.sandbox.push.apple.com`) |
| `HOTWIRE_NATIVE_SHELL_FCM_PROJECT_ID` | `fcm.project_id` |
| `HOTWIRE_NATIVE_SHELL_FCM_SERVICE_ACCOUNT_JSON` | `fcm.service_account_json` |
| `HOTWIRE_NATIVE_SHELL_FCM_SERVICE_ACCOUNT_PATH` | path to the JSON file |

APNs needs the Key ID, Team ID, bundle id, and the `.p8` private key (Apple's token-based auth, not a certificate). FCM needs a Google service account JSON with `firebase.messaging` permission and the project id. The Android app's `google-services.json` stays on the client build. It is not the server credential.

```ruby
HotwireNativeShell::Push.deliver(device_token, title: "Hola", body: "Nuevo post", data: { post_id: post.id })
HotwireNativeShell::Push.deliver_to_owner(user, title: "Hola", body: "Nuevo post")
HotwireNativeShell::Push.deliver_topic("posts", title: "Hola", body: "Nuevo post")
```

## App Store, optional

These are reminders, not a store submission.

**Guideline 4.8.** If the native app shows a third-party login (Google, GitHub, and the like), it also needs Sign in with Apple or an equivalent private option. Until `config.sign_in_with_apple = true`, `native_oauth_allowed?` is false inside the app and true on the website:

```erb
<% if native_oauth_allowed? %>
  <%= button_to "Google", user_google_oauth2_omniauth_authorize_path %>
<% end %>
```

**Guideline 5.1.1(v).** An app that creates accounts needs in-app account deletion. This gem does not delete users. Set `config.account_deletion_path` to a real route you own, then:

```erb
<%= native_account_deletion_link("Delete account") %>
```

The helper renders nothing until that path is set.

## Tests

From `rails/`:

```sh
bundle install
bundle exec rake test
```

The suite boots a dummy app and checks the flavor JSON, the bundled path-configuration files, the bridge markup, device tokens, and signed APNs / FCM requests (no network). `python3 script/check_contract.py` from the repo root checks that this gem's bridge keys, component names, and placeholder token still match the shell.
