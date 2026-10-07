// Generic capture runner. Jobs come from store/brand.yml `captures`.
// Each job: { file, url, device: iphone|ipad, user_agent: safari|native, locale, full_page, skip_if_url_contains, steps }.
const path = require("path");
const fs = require("fs");
const { execFileSync } = require("child_process");

const REPO = path.resolve(__dirname, "../../..");

const USER_AGENTS = {
  iphone: {
    safari: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
    native: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Hotwire Native iOS; Turbo Native iOS",
  },
  ipad: {
    safari: "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
    native: "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Hotwire Native iOS; Turbo Native iOS",
  },
};

const VIEWPORTS = {
  iphone: { width: 390, height: 844, deviceScaleFactor: 3 },
  ipad: { width: 1032, height: 1376, deviceScaleFactor: 2 },
};

function loadBrand(brandPath) {
  const raw = execFileSync("python3", [path.join(REPO, "tools", "store-screenshots", "load_brand.py"), brandPath], { encoding: "utf8" });
  return JSON.parse(raw);
}

function resolveInRepo(rel) {
  return path.isAbsolute(rel) ? rel : path.resolve(REPO, rel);
}

async function applyStep(page, step, assetsDir) {
  if (step.add_class) {
    const className = step.add_class === true ? "hotwire-native" : String(step.add_class);
    await page.evaluate((name) => document.body.classList.add(name), className);
    return;
  }
  if (step.wait_ms) {
    await page.waitForTimeout(Number(step.wait_ms));
    return;
  }
  if (step.click) {
    await page.click(step.click);
    return;
  }
  if (step.type) {
    const text = typeof step.type === "string" ? step.type : step.type.text;
    const delay = typeof step.type === "object" && step.type.delay ? step.type.delay : 0;
    await page.keyboard.type(text, { delay });
    return;
  }
  if (step.blur) {
    await page.evaluate(() => document.activeElement && document.activeElement.blur());
    return;
  }
  if (step.hide) {
    const selectors = Array.isArray(step.hide) ? step.hide : [step.hide];
    await page.evaluate((list) => {
      for (const selector of list) {
        document.querySelectorAll(selector).forEach((el) => { el.style.display = "none"; });
      }
    }, selectors);
    return;
  }
  if (step.remove_link_card) {
    const href = step.remove_link_card.href_contains;
    const group = step.remove_link_card.group_href_contains || href;
    const info = await page.evaluate(({ href, group }) => {
      const links = [...document.querySelectorAll("a")].filter((el) => (el.getAttribute("href") || "").includes(href));
      if (!links.length) return "none";
      let el = links[0];
      while (
        el.parentElement &&
        el.parentElement.querySelectorAll(`a[href*="${group}"]`).length <= links.length &&
        el.parentElement !== document.body
      ) {
        el = el.parentElement;
      }
      el.remove();
      return "removed";
    }, { href, group });
    console.log("  remove_link_card", href, info);
    return;
  }
  if (step.clip_around_input) {
    const clip = step.clip_around_input;
    const box = await page.evaluate(({ input, extra }) => {
      const field = document.querySelector(input);
      if (!field) return null;
      const label = document.querySelector(`label[for="${field.id}"]`) || field.closest("div")?.previousElementSibling;
      const group = field.closest(".input-group") || field.parentElement;
      const extraEl = extra
        ? [...document.querySelectorAll("*")].find((el) => el.children.length === 0 && el.textContent.trim() === extra)
        : null;
      const rects = [label, group, extraEl].filter(Boolean).map((el) => el.getBoundingClientRect());
      if (!rects.length) return null;
      const x = Math.min(...rects.map((r) => r.left)) - 12;
      const y = Math.min(...rects.map((r) => r.top)) - 10;
      const right = Math.max(...rects.map((r) => r.right)) + 12;
      const bottom = Math.max(...rects.map((r) => r.bottom)) + 12;
      return { x, y, width: right - x, height: bottom - y };
    }, { input: clip.input, extra: clip.extra_text || "" });
    if (!box) {
      console.log("  clip skipped; input not found", clip.input);
      return;
    }
    const out = path.join(assetsDir, clip.out);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    await page.screenshot({ path: out, clip: box });
    console.log("  clip", clip.out, JSON.stringify(box));
  }
}

async function runCaptures(device) {
  const brandPath = path.resolve(REPO, process.argv.includes("--brand")
    ? process.argv[process.argv.indexOf("--brand") + 1]
    : "store/brand.yml");
  const brand = loadBrand(brandPath);
  const capturesDir = resolveInRepo(brand.captures_dir || "store/captures");
  const assetsDir = resolveInRepo(brand.assets_dir || "store/assets");
  fs.mkdirSync(capturesDir, { recursive: true });
  const jobs = (brand.captures || []).filter((job) => (job.device || "iphone") === device);
  if (!jobs.length) {
    console.log("no " + device + " captures in " + path.relative(REPO, brandPath));
    return;
  }
  const { chromium } = require("playwright");
  const browser = await chromium.launch();
  try {
    for (const job of jobs) {
      const viewport = VIEWPORTS[device];
      const agentKind = job.user_agent || "safari";
      const userAgent = USER_AGENTS[device][agentKind];
      if (!userAgent) throw new Error("unknown user_agent " + agentKind);
      const context = await browser.newContext({
        viewport: { width: viewport.width, height: viewport.height },
        deviceScaleFactor: viewport.deviceScaleFactor,
        isMobile: true,
        hasTouch: true,
        userAgent,
        locale: job.locale || "en-US",
      });
      const page = await context.newPage();
      try {
        const response = await page.goto(job.url, { waitUntil: "domcontentloaded", timeout: 45000 });
        await page.waitForLoadState("load", { timeout: 15000 }).catch(() => {});
        await page.waitForTimeout(job.wait_ms || 1500);
        console.log(job.file, response && response.status(), "->", page.url());
        if (job.skip_if_url_contains && page.url().includes(job.skip_if_url_contains)) {
          console.log("  skipped");
          continue;
        }
        for (const step of job.steps || []) await applyStep(page, step, assetsDir);
        const dest = path.join(capturesDir, job.file);
        await page.screenshot({ path: dest });
        if (job.full_page) {
          const full = dest.replace(/\.png$/, "_full.png");
          await page.screenshot({ path: full, fullPage: true });
        }
      } catch (err) {
        console.log(job.file, "ERR", err.message.split("\n")[0]);
      } finally {
        await context.close();
      }
    }
  } finally {
    await browser.close();
  }
}

module.exports = { runCaptures };
