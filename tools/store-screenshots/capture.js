#!/usr/bin/env node
// iPhone captures declared in store/brand.yml (device: iphone).
// 390x844 @3x -> 1170x2532, no status bar. The Portada frame draws the status bar and nav bar.
const { runCaptures } = require("./shared/capture_run");

runCaptures("iphone").catch((err) => {
  console.error(err);
  process.exit(1);
});
