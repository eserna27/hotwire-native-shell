// Renders the Portada store set from store/brand.yml.
// Usage (from the repo root or from this directory):
//   node tools/store-screenshots/render.js
//   node tools/store-screenshots/render.js --lang es --fmt ios
const { chromium } = require("playwright");
const path = require("path");
const fs = require("fs");
const { execFileSync } = require("child_process");
const FORMATS = require("./formats");

const HERE = __dirname;
const REPO = path.resolve(HERE, "../..");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

function fileUrl(abs) {
  const parts = path.resolve(abs).split(path.sep);
  return "file://" + parts.map((part, i) => (i === 0 ? "" : encodeURIComponent(part))).join("/");
}

function loadBrand(brandPath) {
  const raw = execFileSync("python3", [path.join(HERE, "load_brand.py"), brandPath], { encoding: "utf8" });
  return JSON.parse(raw);
}

function resolveInRepo(rel) {
  if (!rel) return null;
  return path.isAbsolute(rel) ? rel : path.resolve(REPO, rel);
}

function rewritePopouts(locales, assetsDir) {
  for (const locale of Object.values(locales || {})) {
    for (const slide of locale.slides || []) {
      for (const key of ["popout", "popoutIpad"]) {
        const value = slide[key];
        if (value && !String(value).startsWith("file:")) {
          slide[key] = fileUrl(path.join(assetsDir, value));
        }
      }
    }
  }
  return locales;
}

(async () => {
  const brandPath = path.resolve(REPO, arg("--brand") || "store/brand.yml");
  const brand = loadBrand(brandPath);
  const capturesDir = resolveInRepo(brand.captures_dir || "store/captures");
  const assetsDir = resolveInRepo(brand.assets_dir || "store/assets");
  const outputDir = resolveInRepo(brand.output_dir || "store/screenshots");
  const logo = resolveInRepo(brand.logo);
  const runtime = {
    colors: brand.colors,
    fonts: brand.fonts,
    display_name: brand.display_name,
    status_time: brand.status_time || "9:41",
    logo_uri: logo ? fileUrl(logo) : "",
    captures_uri: fileUrl(capturesDir),
    assets_uri: fileUrl(assetsDir),
    feature_screen: brand.feature_screen || "",
    feature_nav_title: brand.feature_nav_title || "",
    locales: rewritePopouts(structuredClone(brand.locales || {}), assetsDir),
  };
  const runtimePath = path.join(HERE, "template", "brand.runtime.js");
  fs.writeFileSync(runtimePath, "window.BRAND = " + JSON.stringify(runtime) + ";\n");

  const onlyLang = arg("--lang");
  const onlyFmt = arg("--fmt");
  const langs = onlyLang ? [onlyLang] : Object.keys(runtime.locales);
  const fmts = onlyFmt && onlyFmt !== "feature" ? [onlyFmt] : Object.keys(FORMATS).filter((key) => key !== "feature");
  const wantFeature = !onlyFmt || onlyFmt === "feature";
  if (onlyFmt && onlyFmt !== "feature" && !FORMATS[onlyFmt]) {
    console.error("unknown format " + onlyFmt);
    process.exit(1);
  }

  const browser = await chromium.launch();
  try {
    for (const lang of langs) {
      if (!runtime.locales[lang]) {
        console.error("brand.yml has no locale " + lang);
        process.exit(1);
      }
      if (onlyFmt !== "feature") {
        for (const fmt of fmts) {
          const spec = FORMATS[fmt];
          const dir = path.join(outputDir, lang, spec.dir);
          fs.rmSync(dir, { recursive: true, force: true });
          fs.mkdirSync(dir, { recursive: true });
          const page = await browser.newPage({ viewport: { width: spec.W, height: spec.H }, deviceScaleFactor: 1 });
          page.on("pageerror", (err) => console.log("[err]", err.message));
          await page.goto("file://" + path.join(HERE, "template", "index.html") + `?lang=${lang}&fmt=${fmt}`);
          await page.waitForFunction(() => window.READY === true, null, { timeout: 30000 });
          const measured = await page.evaluate(() => ({
            n: SLIDE_COUNT,
            ids: SLIDE_IDS,
            W: SLIDE_W,
            H: SLIDE_H,
            hs: HEADLINE_PX,
            pending: CONTENT.slides.filter((slide) => !slide._src).map((slide) => slide.id + " -> " + (slide._list && slide._list[0])),
          }));
          if (measured.W !== spec.W || measured.H !== spec.H) {
            throw new Error(`${lang}/${fmt} rendered ${measured.W}x${measured.H}, expected ${spec.W}x${spec.H}`);
          }
          await page.setViewportSize({ width: measured.W * measured.n, height: measured.H });
          await page.waitForTimeout(300);
          for (let i = 0; i < measured.n; i++) {
            await page.screenshot({
              path: path.join(dir, `${measured.ids[i]}.png`),
              clip: { x: i * measured.W, y: 0, width: measured.W, height: measured.H },
            });
          }
          const pending = measured.pending.length ? `, placeholders: ${measured.pending.join("; ")}` : "";
          console.log(`${lang}/${fmt}: ${measured.n} slides ${measured.W}x${measured.H}, headline ${measured.hs}px${pending}`);
          await page.close();
        }
      }
      if (wantFeature) {
        const feature = FORMATS.feature;
        fs.mkdirSync(path.join(outputDir, lang), { recursive: true });
        const page = await browser.newPage({ viewport: { width: feature.W, height: feature.H }, deviceScaleFactor: 1 });
        await page.goto("file://" + path.join(HERE, "template", "feature.html") + `?lang=${lang}`);
        await page.waitForFunction(() => window.READY === true, null, { timeout: 30000 });
        const out = path.join(outputDir, lang, feature.file);
        await page.screenshot({ path: out });
        console.log(`${lang}/feature: ${feature.W}x${feature.H} -> ${path.relative(REPO, out)}`);
        await page.close();
      }
    }
  } finally {
    await browser.close();
  }

  if (!onlyLang && !onlyFmt) {
    execFileSync("python3", [path.join(HERE, "previews.py"), outputDir], { stdio: "inherit" });
  }
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
