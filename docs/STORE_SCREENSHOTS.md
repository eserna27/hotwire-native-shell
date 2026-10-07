# App Store and Play screenshots

The poster template, device frames, and capture scripts live in [`tools/store-screenshots/`](../tools/store-screenshots/). They are the same Portada layout for every client: a headline, a CSS phone or tablet frame, and a panorama. All of the brand content lives in [`store/brand.yml`](../store/brand.yml): copy per locale, colors, font names, the logo, the URLs to capture, the captures folder, and drop-in filenames such as `app_editor.png` and `ipad_editor.png`.

The committed `store/brand.yml` is the itsjustmy.blog set in Spanish and English. `bin/new-app` writes a starter `store/brand.yml` for the next client. Edit that file before you render.

The renderer drives Chromium through [Playwright](https://playwright.dev/). Fonts ship in `tools/store-screenshots/shared/fonts/` (Bodoni Moda, Archivo, IBM Plex Mono, Inter, and the other families in `fonts.css`, under the SIL Open Font License or Apache 2.0). `fonts` in `store/brand.yml` picks the families the template uses.

## Sizes

One `node render.js` writes every locale in `store/brand.yml` at these canvases:

| Set | Pixels | File |
| --- | --- | --- |
| App Store iPhone 6.9" portrait | 1320 × 2868 | `store/screenshots/<lang>/appstore-6.9_1320x2868/*.png` |
| App Store iPad 13" portrait | 2064 × 2752 | `store/screenshots/<lang>/appstore-ipad-13_2064x2752/*.png` |
| Google Play phone | 1080 × 1920 | `store/screenshots/<lang>/googleplay_1080x1920/*.png` |
| Google Play feature graphic | 1024 × 500 | `store/screenshots/<lang>/googleplay_feature-graphic_1024x500.png` |

1320 × 2868 is the App Store screenshot size for a 6.9-inch iPhone. 2064 × 2752 is the size for a 13-inch iPad. Play phone screenshots must be between 320 px and 3840 px on each side; 1080 × 1920 is the 9:16 size this template emits. The Play feature graphic is required at 1024 × 500.

iPhone and Play posters share `screen.srcs` and the CSS phone frame. iPad posters use `screen.ipad` and the CSS tablet frame. An iPhone PNG does not fill an iPad slide.

The command also writes a panorama per locale and format, plus `store/screenshots/contact-sheet.png`, and prints `ALL SIZES OK` when every file matches the table.

## Install

```sh
cd tools/store-screenshots
npm install
npx playwright install chromium
```

Rendering the contact sheet needs Pillow (`python3-pil`) and DejaVu Sans.

## Capture public pages

Jobs are the `captures` list in `store/brand.yml`. Each job has a `url`, a `device` (`iphone` or `ipad`), a `user_agent` (`safari` or `native`), and optional `steps` (`add_class`, `click`, `type`, `hide`, `remove_link_card`, `clip_around_input`, `wait_ms`). Output filenames are relative to `captures_dir` (default `store/captures/`).

```sh
cd tools/store-screenshots
node capture.js          # device: iphone → 390×844 at 3x = 1170×2532
node capture_ipad.js     # device: ipad   → 1032×1376 at 2x = 2064×2752
```

Those viewports are the page only. They have no operating-system status bar. The frame draws the status bar, and the nav bar when the slide sets `screen.nav`.

`user_agent: native` sends a Hotwire Native user agent. `add_class: hotwire-native` is the class the Rails layout uses to hide `nav.navbar`. See [NATIVE_UI.md](NATIVE_UI.md).

## Drop-ins from the simulator or emulator

Screens that need a signed-in session are `drop_ins` in `store/brand.yml`. The itsjustmy set uses:

| File | Canvas | Use |
| --- | --- | --- |
| `app_editor.png` | 1170 × 2532 | iPhone editor |
| `app_dashboard.png` | 1170 × 2532 | iPhone dashboard (`app_posts.png` is the fallback) |
| `ipad_editor.png` | 2064 × 2752 | iPad editor |
| `ipad_dashboard.png` | 2064 × 2752 | iPad dashboard (`ipad_posts.png` is the fallback) |

Put the PNG in `store/captures/` under that exact name. While a file is missing, the slide shows a hatched screen labelled with the filename.

### iOS Simulator

1. Boot a simulator whose screen is 390 × 844 points at 3× (1170 × 2532 pixels) for iPhone captures. iPhone 14 and iPhone 15 use that size. For iPad captures, use a 13-inch iPad simulator and export 2064 × 2752 (1032 × 1376 points at 2×).
2. Open the signed-in screen in the Hotwire Native app, or in Simulator Safari with the page's native chrome hidden.
3. Capture the web content only. The Portada frame draws the status bar and, when `screen.nav` is set, the navigation bar, so leave both out of the PNG. Crop them if the screenshot includes the system status bar.
4. Save the file under the name in `drop_ins`.

`xcrun simctl io booted screenshot /tmp/screen.png` writes the simulator framebuffer, which includes the status bar. Crop that strip before dropping the file in.

### Android emulator

Play posters reuse the iPhone captures (`screen.srcs`), not a separate Android screenshot. Use the emulator when you want a picture of the Android shell itself:

1. Start an emulator and sign in.
2. Capture the web content at the same pixel sizes as the table above (1170 × 2532 for a phone drop-in, 2064 × 2752 for an iPad drop-in used on the tablet posters).
3. Crop the status bar and the native toolbar when the slide's `screen.nav` draws that bar.

`adb exec-out screencap -p > store/captures/app_editor.png` is the raw framebuffer. Crop it to the size named in `drop_ins` before rendering.

## Render

From the repo root:

```sh
node tools/store-screenshots/render.js
```

One locale or one canvas:

```sh
node tools/store-screenshots/render.js --lang es --fmt ios
node tools/store-screenshots/render.js --lang en --fmt ipad
node tools/store-screenshots/render.js --lang es --fmt play
node tools/store-screenshots/render.js --lang es --fmt feature
```

`fmt` is `ios` (1320 × 2868), `ipad` (2064 × 2752), `play` (1080 × 1920), or `feature` (1024 × 500). Output is gitignored under `store/screenshots/`.

To change a headline, a color, or which capture a slide uses, edit `store/brand.yml` and render again. The HTML template does not contain the client name.
