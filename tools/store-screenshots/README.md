# Store screenshots

Generic Portada renderer for this shell. Brand copy, colors, fonts, the logo, capture URLs, and drop-in filenames come from [`store/brand.yml`](../../store/brand.yml).

How to capture from the simulator or emulator, render, and which sizes each store asks for: [docs/STORE_SCREENSHOTS.md](../../docs/STORE_SCREENSHOTS.md).

```sh
npm install
npx playwright install chromium
node capture.js
node capture_ipad.js
node render.js
```
