// Builds the documentation pages of outskirts.dev from the Markdown files of docs/ and from CHANGELOG.md.
// Output: public/docs/<page>/index.html, the images they use, and public/sitemap.xml. Nothing here is committed.
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import MarkdownIt from "markdown-it";
import {
  ORIGIN,
  PUBLIC_DIR,
  REPO_DIR,
  REPO_URL,
  latestRelease,
  loadPages,
  navigation,
  pageURL,
  resolveLink,
  uniqueSlugger,
} from "./lib/docs.mjs";

const OUT_DIR = join(PUBLIC_DIR, "docs");
const STACKED_COLUMNS = 3;
const PROSE_LENGTH = 60;
// Past this many h2 and h3 headings, the table of contents lists the h2 headings only.
const MAX_TOC_ENTRIES = 40;
const CALLOUTS = { NOTE: "Note", TIP: "Tip", IMPORTANT: "Important", WARNING: "Warning", CAUTION: "Caution" };

const pages = loadPages();
const groups = navigation(pages);
const ordered = [pages.find((p) => p.name === ""), ...groups.flatMap((g) => g.items.map((i) => i.page))];
const release = latestRelease();
const footer = readFileSync(join(PUBLIC_DIR, "index.html"), "utf8").match(/<footer>[\s\S]*?<\/footer>/)?.[0];
if (!footer) throw new Error("public/index.html has no <footer> to share");

for (const page of pages) {
  if (!ordered.includes(page)) throw new Error(`${page.source} is not in the navigation of docs/README.md`);
}

rmSync(OUT_DIR, { recursive: true, force: true });
const images = new Map();

for (const page of pages) {
  const html = renderPage(page);
  const dir = join(OUT_DIR, page.name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "index.html"), html);
}

for (const [source, target] of images) {
  mkdirSync(dirname(target), { recursive: true });
  copyFileSync(source, target);
}

const urls = ["/", ...pages.map((p) => pageURL(p.name))];
writeFileSync(
  join(PUBLIC_DIR, "sitemap.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls
    .map((u) => `<url><loc>${ORIGIN}${u}</loc></url>`)
    .join("\n")}\n</urlset>\n`,
);
console.log(`built ${pages.length} documentation pages, ${images.size} images, sitemap with ${urls.length} URLs`);

// MARK: - Rendering

function markdown(page) {
  const md = new MarkdownIt({ html: false, linkify: false, typographer: false });
  const slug = uniqueSlugger();
  const headings = [];

  md.core.ruler.push("outskirts", (state) => {
    const tokens = state.tokens;
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i];
      if (token.type === "heading_open") {
        const text = tokens[i + 1].children.filter((c) => c.type === "text" || c.type === "code_inline").map((c) => c.content).join("");
        const id = slug(text);
        token.attrSet("id", id);
        token.meta = { id, text };
        if (token.tag === "h2" || token.tag === "h3") headings.push({ level: Number(token.tag[1]), id, text, inline: tokens[i + 1] });
      }
      if (token.type === "blockquote_open") calloutize(tokens, i, state);
      if (token.type === "table_open") labelCells(tokens, i);
    }
  });

  md.renderer.rules.heading_close = (tokens, i) => {
    const open = tokens[i - 2];
    if (open.tag === "h1") return "</h1>\n";
    return `<a class="anchor" href="#${open.meta.id}" aria-label="Link to ${escapeAttr(open.meta.text)}">#</a></${open.tag}>\n`;
  };

  md.renderer.rules.link_open = (tokens, i, options, env, self) => {
    const href = tokens[i].attrGet("href");
    tokens[i].attrSet("href", resolveLink(href, page.file));
    return self.renderToken(tokens, i, options);
  };

  // A table too wide for a phone scrolls inside its box, never the page; its cells keep whole words.
  md.renderer.rules.table_open = (tokens, i, options, env, self) => `<div class="table-scroll">\n${self.renderToken(tokens, i, options)}`;
  md.renderer.rules.table_close = (tokens, i, options, env, self) => `${self.renderToken(tokens, i, options)}</div>\n`;

  md.renderer.rules.image = (tokens, i) => {
    const token = tokens[i];
    const src = token.attrGet("src");
    const alt = token.children.map((c) => c.content).join("");
    if (!src.startsWith("../assets/")) throw new Error(`${page.source}: image ${src} must live under assets/`);
    const repoPath = src.slice(3);
    const source = join(REPO_DIR, repoPath);
    images.set(source, join(OUT_DIR, repoPath));
    const { width, height } = pngSize(source);
    return `<img src="/docs/${repoPath}" alt="${escapeAttr(alt)}" width="${width}" height="${height}" loading="lazy" decoding="async">`;
  };

  return { md, headings };
}

// A table of STACKED_COLUMNS columns or more reads as one card per row on a phone: each cell carries its header
// as data-label, which the stylesheet shows in front of the value. A column of sentences (PROSE_LENGTH characters
// per cell on average) is marked "prose": code may break inside it, while code in short columns stays on one line.
function labelCells(tokens, index) {
  const labels = [];
  const columns = [];
  let column = 0;
  for (let i = index + 1; tokens[i].type !== "table_close"; i++) {
    const token = tokens[i];
    if (token.type === "tr_open") column = 0;
    if (token.type === "th_open") labels.push(tokens[i + 1].children.map((c) => c.content).join(""));
    if (token.type === "td_open") {
      token.attrSet("data-label", labels[column]);
      (columns[column] ??= []).push({ token, length: tokens[i + 1].content.length });
      column++;
    }
  }
  for (const cells of columns) {
    if (cells.reduce((sum, c) => sum + c.length, 0) / cells.length >= PROSE_LENGTH) cells.forEach((c) => c.token.attrSet("class", "prose"));
  }
  if (labels.length >= STACKED_COLUMNS) tokens[index].attrSet("class", "stacked");
}

function calloutize(tokens, index, state) {
  const paragraph = tokens[index + 1];
  const inline = tokens[index + 2];
  if (paragraph?.type !== "paragraph_open" || inline?.type !== "inline") return;
  const match = inline.content.match(/^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*/);
  if (!match) return;
  const kind = match[1];
  tokens[index].attrSet("class", `callout callout-${kind.toLowerCase()}`);
  const rest = inline.content.slice(match[0].length);
  const title = new state.Token("html_block", "", 0);
  title.content = `<p class="callout-title">${CALLOUTS[kind]}</p>\n`;
  if (rest.trim() === "") {
    tokens.splice(index + 1, 3, title);
  } else {
    inline.content = rest;
    const children = inline.children;
    const first = children.findIndex((c) => c.type === "text");
    children[first].content = children[first].content.replace(/^\[!\w+\]\s*/, "");
    if (children[first].content === "" && children[first + 1]?.type === "softbreak") children.splice(first, 2);
    tokens.splice(index + 1, 0, title);
  }
}

function renderPage(page) {
  const { md, headings } = markdown(page);
  let body = md.render(page.body);

  const changelog = page.name === "changelog";
  const toc = tableOfContents(headings, { topLevelOnly: changelog || headings.length > MAX_TOC_ENTRIES, closed: changelog });
  const status =
    page.name === ""
      ? `<p class="status">Latest release: <a href="/docs/changelog/#${release.slug}">${release.version}</a> (${release.date}). See what comes next on the <a href="/docs/roadmap/">roadmap</a>.</p>\n`
      : "";
  const firstSection = body.indexOf("<h2");
  if (firstSection >= 0) body = body.slice(0, firstSection) + status + toc + body.slice(firstSection);

  const index = ordered.indexOf(page);
  const previous = ordered[index - 1];
  const next = ordered[index + 1];
  const title = page.name === "" ? "Documentation | outskirts" : `${page.title} | outskirts documentation`;
  const url = `${ORIGIN}${pageURL(page.name)}`;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHTML(title)}</title>
<meta name="description" content="${escapeAttr(page.description)}">
<link rel="canonical" href="${url}">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="stylesheet" href="/style.css">
<meta property="og:type" content="article">
<meta property="og:site_name" content="outskirts">
<meta property="og:title" content="${escapeAttr(page.title)}">
<meta property="og:description" content="${escapeAttr(page.description)}">
<meta property="og:url" content="${url}">
<meta property="og:image" content="${ORIGIN}/social-preview.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeAttr(page.title)}">
<meta name="twitter:description" content="${escapeAttr(page.description)}">
<meta name="twitter:image" content="${ORIGIN}/social-preview.png">
</head>
<body class="docs">
<a class="skip" href="#content">Skip to content</a>
<header class="topbar">
<a class="brand" href="/"><picture>
<source srcset="/outskirts-logo-dark.svg" media="(prefers-color-scheme: dark)">
<img src="/outskirts-logo.svg" alt="outskirts home" width="922" height="256">
</picture></a>
<nav class="topnav" aria-label="Site"><a href="/docs/"${page.name === "" ? ' aria-current="page"' : ""}>Documentation</a> <a href="${REPO_URL}">GitHub</a></nav>
</header>
<div class="layout">
<nav class="sidebar" aria-label="Documentation">
${navList(page)}
</nav>
<main id="content">
<details class="mobile-nav">
<summary>Documentation menu</summary>
${navList(page)}
</details>
<article>
${body}</article>
<nav class="pager" aria-label="Previous and next pages">
${previous ? `<a class="previous" href="${pageURL(previous.name)}"><span>Previous</span> ${escapeHTML(previous.title)}</a>` : "<span></span>"}
${next ? `<a class="next" href="${pageURL(next.name)}"><span>Next</span> ${escapeHTML(next.title)}</a>` : "<span></span>"}
</nav>
<p class="edit">${editLink(page)}</p>
</main>
</div>
${footer}
</body>
</html>
`;
}

function navList(current) {
  const overview = `<ul>\n<li><a href="/docs/"${current.name === "" ? ' aria-current="page"' : ""}>Overview</a></li>\n</ul>\n`;
  return overview + groups
    .map(
      (group) =>
        `<p class="nav-group">${escapeHTML(group.title)}</p>\n<ul>\n${group.items
          .map((item) => {
            const currentAttr = item.page === current ? ' aria-current="page"' : "";
            return `<li><a href="${pageURL(item.page.name)}"${currentAttr}>${escapeHTML(item.title)}</a></li>`;
          })
          .join("\n")}\n</ul>`,
    )
    .join("\n");
}

function tableOfContents(headings, { topLevelOnly, closed }) {
  if (headings.filter((h) => h.level === 2).length < 2) return "";
  const items = [];
  for (const heading of headings) {
    const link = `<a href="#${heading.id}">${renderInline(heading.inline)}</a>`;
    if (heading.level === 2 || items.length === 0) items.push({ link, children: [] });
    else if (!topLevelOnly) items.at(-1).children.push(link);
  }
  const list = items
    .map((item) => `<li>${item.link}${item.children.length ? `<ul>${item.children.map((c) => `<li>${c}</li>`).join("")}</ul>` : ""}</li>`)
    .join("\n");
  return `<details class="toc"${closed ? "" : " open"}>\n<summary>On this page</summary>\n<ul>\n${list}\n</ul>\n</details>\n`;
}

function renderInline(inline) {
  return inline.children
    .map((c) => (c.type === "code_inline" ? `<code>${escapeHTML(c.content)}</code>` : c.type === "text" ? escapeHTML(c.content) : ""))
    .join("");
}

function editLink(page) {
  if (page.name === "changelog") {
    return `Generated from <a href="${REPO_URL}/blob/master/CHANGELOG.md">CHANGELOG.md</a>, filled by each release.`;
  }
  if (page.name === "options") {
    return `Generated from <a href="${REPO_URL}/blob/master/outskirts.schema.json">outskirts.schema.json</a>; edit the descriptions in <a href="${REPO_URL}/blob/master/Sources/Configuration/SettingDescriptions.swift">SettingDescriptions.swift</a>.`;
  }
  return `<a href="${REPO_URL}/edit/master/${page.source}">Edit this page on GitHub</a>`;
}

// MARK: - Helpers

function pngSize(file) {
  const data = readFileSync(file);
  if (data.toString("ascii", 12, 16) !== "IHDR") throw new Error(`${file} is not a PNG`);
  return { width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
}

function escapeHTML(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function escapeAttr(text) {
  return escapeHTML(text).replace(/"/g, "&quot;");
}
