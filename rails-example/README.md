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
```

`GET /native/config` reads [`flavors/itsjustmy/assets/native/config.json`](../flavors/itsjustmy/assets/native/config.json). The path-configuration route reads the JSON bundled in the Android app. One file, two consumers.

To load the sketch in the emulator, set the flavor `base_url` to `http://10.0.2.2:9292` (the host machine from the Android emulator). Debug builds allow cleartext to `10.0.2.2` and `localhost`. Release builds do not.

## Copy into a real Rails app

Add the routes in [`config/routes.rb`](config/routes.rb):

- `GET /native/config` → `Native::ConfigsController#show`
- `GET /configurations/android_v1.json` → path configuration for Hotwire Native Android
- `GET /configurations/ios_v1.json` → same document until iOS needs its own rules

[`app/controllers/native/configs_controller.rb`](app/controllers/native/configs_controller.rb) renders JSON. In the client app, replace `NativeConfig.payload` with a hash or a JSON file that lives in that app. Do not read this repository from production.

Keep the response keys in [docs/CONTRACT.md](../docs/CONTRACT.md). The Android shell ignores unknown keys and treats missing bridge flags as `false`.

Install `@hotwired/hotwire-native-bridge` on the server before the bridge Stimulus controllers in [docs/BRIDGES.md](../docs/BRIDGES.md) will run. The sketch does not ship that package.
