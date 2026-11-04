import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const SITE_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
export const REPO_DIR = resolve(SITE_DIR, "..");
export const DOCS_DIR = join(REPO_DIR, "docs");
export const PUBLIC_DIR = join(SITE_DIR, "public");
export const ORIGIN = "https://outskirts.dev";
export const REPO_URL = "https://github.com/tiny-earth-moon/outskirts";
export const MAX_CODE_LINE = 64;

/** GitHub's heading slug: lowercase, punctuation removed except `-` and `_`, spaces become `-`. */
export function slugify(text) {
  return text
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s_-]/gu, "")
    .replace(/\s/g, "-");
}

/** Assigns GitHub-style unique slugs (`x`, `x-1`, `x-2`) in document order. */
export function uniqueSlugger() {
  const seen = new Map();
  return (text) => {
    const base = slugify(text);
    const count = seen.get(base) ?? 0;
    seen.set(base, count + 1);
    return count === 0 ? base : `${base}-${count}`;
  };
}

/** Text of a Markdown heading as GitHub slugs it: link targets, inline code and emphasis markers dropped. */
export function headingText(markdown) {
  return markdown
    .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
    .replace(/[`*]/g, "")
    .replace(/(^|\s)_|_(\s|$)/g, "$1$2");
}

export function parseFrontMatter(source, file) {
  const match = source.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) throw new Error(`${file}: missing front matter with a description`);
  const data = {};
  for (const line of match[1].split("\n")) {
    const pair = line.match(/^([a-z_]+):\s*(.*)$/);
    if (pair) data[pair[1]] = pair[2];
  }
  if (!data.description) throw new Error(`${file}: front matter has no description`);
  return { data, body: source.slice(match[0].length) };
}

/** Headings of a Markdown body outside fenced code, with their level, text and slug. */
export function markdownHeadings(body) {
  const slug = uniqueSlugger();
  const headings = [];
  let fence = null;
  for (const line of body.split("\n")) {
    const marker = line.match(/^\s*(`{3,}|~{3,})/);
    if (marker) {
      if (!fence) fence = marker[1];
      else if (marker[1].startsWith(fence)) fence = null;
      continue;
    }
    if (fence) continue;
    const heading = line.match(/^(#{1,6})\s+(.*?)\s*#*\s*$/);
    if (heading) headings[headings.length] = { level: heading[1].length, text: heading[2], slug: slug(headingText(heading[2])) };
  }
  return headings;
}

/** Name of the page a docs file is published as: `README.md` is the docs home, `../CHANGELOG.md` the changelog. */
export function pageName(file) {
  if (file === "README.md") return "";
  if (file === "../CHANGELOG.md") return "changelog";
  return file.replace(/\.md$/, "");
}

export function pageURL(name) {
  return name ? `/docs/${name}/` : "/docs/";
}

/** The pages of the documentation: every `docs/*.md`, plus the changelog generated from CHANGELOG.md. */
export function loadPages() {
  const files = readdirSync(DOCS_DIR).filter((f) => f.endsWith(".md")).sort();
  const pages = files.map((file) => {
    const source = readFileSync(join(DOCS_DIR, file), "utf8");
    const { data, body } = parseFrontMatter(source, `docs/${file}`);
    const title = body.match(/^# (.+)$/m)?.[1];
    if (!title) throw new Error(`docs/${file}: missing '# Title'`);
    return { file, source: `docs/${file}`, name: pageName(file), title, description: data.description, body };
  });
  return [...pages, changelogPage()];
}

export function changelogPage() {
  const source = readFileSync(join(REPO_DIR, "CHANGELOG.md"), "utf8");
  const body =
    "# Changelog\n\nEvery change of outskirts, newest first. The `master` section lists what is merged and not released yet. " +
    "This page is generated from [CHANGELOG.md](https://github.com/tiny-earth-moon/outskirts/blob/master/CHANGELOG.md) at each build.\n\n" +
    source.replace(/^##### (.+)$/gm, "### $1");
  return {
    file: "../CHANGELOG.md",
    source: "CHANGELOG.md",
    name: "changelog",
    title: "Changelog",
    description: "Every release of outskirts, newest first: breaking changes, enhancements and bug fixes, generated from the CHANGELOG.md of the repository.",
    body,
  };
}

/** Latest released version and date, from the first `## X.Y.Z (date)` heading of CHANGELOG.md. */
export function latestRelease() {
  const source = readFileSync(join(REPO_DIR, "CHANGELOG.md"), "utf8");
  const match = source.match(/^## (\d+\.\d+\.\d+) \((\d{4}-\d{2}-\d{2})\)$/m);
  if (!match) throw new Error("CHANGELOG.md: no released version found");
  return { version: match[1], date: match[2], slug: slugify(`${match[1]} (${match[2]})`) };
}

/** Navigation groups, read from the `## Group` sections and `- [Title](file.md)` items of docs/README.md. */
export function navigation(pages) {
  const home = pages.find((p) => p.file === "README.md");
  const groups = [];
  for (const line of home.body.split("\n")) {
    const group = line.match(/^## (.+)$/);
    if (group) groups[groups.length] = { title: group[1], items: [] };
    const item = line.match(/^- \[([^\]]+)\]\(([^)]+)\)$/);
    if (item && groups.length) {
      const page = pages.find((p) => p.file === item[2]);
      if (!page) throw new Error(`docs/README.md: '${item[2]}' is not a documentation page`);
      const items = groups[groups.length - 1].items;
      items[items.length] = { title: item[1], page };
    }
  }
  return groups;
}

/**
 * Resolves a Markdown link written in `fromFile` (a path relative to docs/) to a site URL: another page becomes
 * `/docs/<page>/`, a repository file a GitHub URL; an external URL stays as it is.
 */
export function resolveLink(href, fromFile, { absolute = false } = {}) {
  if (/^(https?:|mailto:)/.test(href)) return href;
  const [path, anchor] = href.split("#");
  const hash = anchor !== undefined ? `#${anchor}` : "";
  const prefix = absolute ? ORIGIN : "";
  if (!path) return absolute ? `${ORIGIN}${pageURL(pageName(fromFile))}${hash}` : hash;
  const repoPath = normalize(`${fromFile.startsWith("../") ? "" : "docs/"}${path}`);
  if (repoPath === "CHANGELOG.md") return `${prefix}${pageURL("changelog")}${hash}`;
  if (/^docs\/[^/]+\.md$/.test(repoPath)) return `${prefix}${pageURL(pageName(repoPath.slice(5)))}${hash}`;
  return `${REPO_URL}/blob/master/${repoPath}${hash}`;
}

function normalize(path) {
  const parts = [];
  for (const part of path.split("/")) {
    if (part === "..") parts.pop();
    else if (part !== "." && part !== "") parts[parts.length] = part;
  }
  return parts.join("/");
}
