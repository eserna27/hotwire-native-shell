# Rails sketch

Minimal server for the shell contract. It is not a generated Rails application and it is not itsjustmy.blog.

## Run the sketch

From `rails-example/`:

```sh
bundle install
bundle exec rackup
```

Then:

```sh
curl -s localhost:9292/native/config
curl -s localhost:9292/configurations/android_v1.json
curl -s localhost:9292/configurations/ios_v1.json
```

`GET /native/config` reads [`flavors/itsjustmy/assets/native/config.json`](../flavors/itsjustmy/assets/native/config.json). Both path-configuration routes read the JSON bundled in the Android app. iOS ignores the Android `uri` values in that document and uses `context` and `pull_to_refresh_enabled`.

To load the sketch in the Android emulator, set the flavor `base_url` to `http://10.0.2.2:9292` (the host machine from the emulator). Debug builds allow cleartext to `10.0.2.2` and `localhost`. The iOS Simulator uses the Mac's loopback, so set `base_url` to `http://localhost:9292` instead. The iOS Debug plist allows cleartext to `localhost` and `127.0.0.1` only. Release builds do not.

## Copy into a real Rails app

Add the routes in [`config/routes.rb`](config/routes.rb):

- `GET /native/config` → `Native::ConfigsController#show`
- `GET /configurations/android_v1.json` → path configuration for Hotwire Native Android
- `GET /configurations/ios_v1.json` → same document until iOS needs its own rules

[`app/controllers/native/configs_controller.rb`](app/controllers/native/configs_controller.rb) renders JSON. In the client app, replace `NativeConfig.payload` with a hash or a JSON file that lives in that app. Do not read this repository from production.

Keep the response keys in [docs/CONTRACT.md](../docs/CONTRACT.md). Both shells ignore unknown keys and treat missing bridge flags as `false`.

`GET /native/config` is the document that turns on bottom tabs. Put an ordered `tabs` array in the hash this app renders. Each item has `id`, `title`, optional `titles` (`es` / `en`), `icon`, and `path` or `url`. The sketch serves the itsjustmy flavor file, which already includes three tabs (`/`, `/acerca`, `/users/sign_in`). Path configuration stays on the `/configurations/*_v1.json` routes. Do not put tabs in that file. `menu` and `overflow-menu` are bridge components on the top bar; they are not tab entries. See [docs/NATIVE_UI.md](../docs/NATIVE_UI.md).

Install `@hotwired/hotwire-native-bridge` on the server before the bridge Stimulus controllers in [docs/BRIDGES.md](../docs/BRIDGES.md) will run. The sketch does not ship that package. Hiding the HTML navbar and dropping the `| itsjustmy.blog` title suffix belong in the real Rails app. The contract is [docs/NATIVE_UI.md](../docs/NATIVE_UI.md).
