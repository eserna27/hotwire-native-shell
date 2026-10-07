#!/usr/bin/env node
// iPad 13" captures declared in store/brand.yml (device: ipad).
// 1032x1376 @2x -> 2064x2752, no status bar. The template draws a CSS tablet frame.
const { runCaptures } = require("./shared/capture_run");

runCaptures("ipad").catch((err) => {
  console.error(err);
  process.exit(1);
});