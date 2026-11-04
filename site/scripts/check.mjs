// Checks the built site in public/ (run `npm run build` first; `npm run check` does both).
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { MAX_CODE_LINE, ORIGIN, PUBLIC_DIR } from "./lib/docs.mjs";

const root = PUBLIC_DIR;
const errors = [];
// The published security.txt; change this hash together with the file, on purpose only.
const SECURITY_TXT_SHA256 = "4d8e9ca4d3c99a251dbe7b4350e03dbafa8588fcd929d77196df34c5dab38036";

const pages = walk(root).filter((f) => f.endsWith(".html"));
const html = new Map(pages.map((p) => [p, readFileSync(join(root, p), "utf8")]));
const ids = new Map([...html].map(([p, h]) => [p, new Set([...h.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]))]));
const docsPages = pages.filter((p) => p.startsWith("docs/"));
const navigation = new Set(
  [...(html.get("docs/index.html") ?? "").matchAll(/<nav class="sidebar"[\s\S]*?<\/nav>/g)].flatMap((m) =>
    [...m[0].matchAll(/href="([^"]+)"/g)].map((l) => l[1]),
  ),
);

if (!docsPages.length) errors.push("public/docs is empty: run 'npm run build' first");

for (const page of pages) {
  const source = html.get(page);
  if (!/<html[^>]*\slang="en"/.test(source)) errors.push(`${page}: missing lang="en"`);
  if (!/<title>[^<]+<\/title>/.test(source)) errors.push(`${page}: missing <title>`);
  if (!/<meta\s+name="description"\s+content="[^"]+"/.test(source)) errors.push(`${page}: missing meta description`);
  if (!/<meta\s+property="og:image"\s+content="[^"]+"/.test(source)) errors.push(`${page}: missing og:image`);
  if (/<style[\s>]|\sstyle="/.test(source)) errors.push(`${page}: inline style; styles belong in style.css`);
  if (/<script(?![^>]*type="application\/ld\+json")/.test(source)) errors.push(`${page}: script; the site works without JavaScript`);
  checkCode(page, source);
  checkLinks(page, source);
}

for (const page of docsPages) {
  const source = html.get(page);
  const url = `/${page.replace(/index\.html$/, "")}`;
  if (!source.includes('<link rel="stylesheet" href="/style.css">')) errors.push(`${page}: does not load /style.css`);
  if (!source.includes('src="/outskirts-logo.svg"') || !source.includes('srcset="/outskirts-logo-dark.svg"')) {
    errors.push(`${page}: does not show the light and dark logo`);
  }
  if (!source.includes(`<link rel="canonical" href="${ORIGIN}${url}">`)) errors.push(`${page}: canonical is not ${ORIGIN}${url}`);
  if (!/<meta property="og:title" content="[^"]+">/.test(source)) errors.push(`${page}: missing og:title`);
  if (!navigation.has(url)) errors.push(`${page}: not in the documentation navigation`);
}

checkStylesheet();
checkSitemap();
checkSecurityTxt();

if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}
console.log(`ok: ${pages.length} pages checked (${docsPages.length} documentation pages), ${formatSize(siteSize())} in public/`);

// MARK: - Checks

/** Code lines longer than MAX_CODE_LINE wrap on a laptop; only a URL, which cannot be split, may exceed it. */
function checkCode(page, source) {
  // The changelog quotes CHANGELOG.md, which only release commits edit: its long lines wrap and never scroll.
  if (page === "docs/changelog/index.html") return;
  for (const block of source.matchAll(/<pre><code[^>]*>([\s\S]*?)<\/code><\/pre>/g)) {
    for (const line of decode(block[1].replace(/<[^>]+>/g, "")).split("\n")) {
      if (line.length <= MAX_CODE_LINE || /:\/\/\S{30,}/.test(line)) continue;
      errors.push(`${page}: code line over ${MAX_CODE_LINE} characters wraps on a laptop: ${line.trim()}`);
    }
  }
}

function checkLinks(page, source) {
  for (const m of source.matchAll(/\s(?:href|src|srcset)="([^"]+)"/g)) {
    const value = decode(m[1]);
    if (/^(https?:|mailto:|data:)/.test(value)) continue;
    const [path, anchor] = value.split("#");
    let target = page;
    if (path) {
      const resolved = path.startsWith("/") ? path.slice(1) : join(page, "..", path);
      target = resolved === "" || resolved.endsWith("/") ? `${resolved}index.html` : resolved;
      if (!existsSync(join(root, target))) {
        errors.push(`${page}: missing local file ${path}`);
        continue;
      }
    }
    if (anchor !== undefined && target.endsWith(".html") && !ids.get(target)?.has(anchor)) {
      errors.push(`${page}: link to ${value}, which has no id="${anchor}"`);
    }
  }
}

/** Colors live only in the custom properties of :root, so that light and dark stay consistent. */
function checkStylesheet() {
  const css = readFileSync(join(root, "style.css"), "utf8").replace(/\/\*[\s\S]*?\*\//g, "");
  for (const rule of css.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
    for (const declaration of rule[2].split(";")) {
      const [property] = declaration.split(":");
      if (property.trim().startsWith("--")) continue;
      if (/#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?|oklch|lab|lch|color-mix)\(|:\s*(?:white|black)\b/.test(declaration)) {
        errors.push(`style.css: color outside the :root custom properties in '${rule[1].trim()}': ${declaration.trim()}`);
      }
    }
  }
  if (!/:root\{[^}]*--bg:/.test(css) || !/@media \(prefers-color-scheme:dark\)\{:root\{/.test(css)) {
    errors.push("style.css: the light and dark :root custom properties are missing");
  }
}

function checkSitemap() {
  const sitemap = existsSync(join(root, "sitemap.xml")) ? readFileSync(join(root, "sitemap.xml"), "utf8") : "";
  const listed = new Set([...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]));
  for (const page of ["index.html", ...docsPages]) {
    const url = `${ORIGIN}/${page.replace(/index\.html$/, "")}`;
    if (!listed.has(url)) errors.push(`sitemap.xml: ${url} is missing`);
  }
  for (const url of listed) {
    const path = url.slice(ORIGIN.length + 1);
    if (!existsSync(join(root, path === "" || path.endsWith("/") ? `${path}index.html` : path))) errors.push(`sitemap.xml: ${url} has no page`);
  }
}

function checkSecurityTxt() {
  const file = join(root, ".well-known", "security.txt");
  const hash = existsSync(file) ? createHash("sha256").update(readFileSync(file)).digest("hex") : "missing";
  if (hash !== SECURITY_TXT_SHA256) {
    errors.push(`.well-known/security.txt changed (sha256 ${hash}); if on purpose, update SECURITY_TXT_SHA256 in scripts/check.mjs`);
  }
}

// MARK: - Helpers

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    return entry.isDirectory() ? walk(path) : [relative(root, path)];
  });
}

function siteSize() {
  return walk(root).reduce((total, file) => total + statSync(join(root, file)).size, 0);
}

function formatSize(bytes) {
  return `${(bytes / 1024).toFixed(0)} KiB`;
}

function decode(text) {
  return text.replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
}
