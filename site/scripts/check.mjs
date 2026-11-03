import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const root = "public";
const pages = readdirSync(root).filter((f) => f.endsWith(".html"));
const errors = [];
const MAX_CODE_LINE = 64;

for (const page of pages) {
  const html = readFileSync(join(root, page), "utf8");
  if (!/<html[^>]*\slang="en"/.test(html)) errors.push(`${page}: missing lang="en"`);
  if (!/<title>[^<]+<\/title>/.test(html)) errors.push(`${page}: missing <title>`);
  if (!/<meta\s+name="description"\s+content="[^"]+"/.test(html)) errors.push(`${page}: missing meta description`);
  if (!/<meta\s+property="og:image"\s+content="[^"]+"/.test(html)) errors.push(`${page}: missing og:image`);
  for (const block of html.matchAll(/<pre><code>([\s\S]*?)<\/code><\/pre>/g)) {
    for (const line of block[1].split("\n")) {
      if (line.length > MAX_CODE_LINE) errors.push(`${page}: code line over ${MAX_CODE_LINE} characters scrolls on a laptop: ${line.trim()}`);
    }
  }
  for (const m of html.matchAll(/\s(?:href|src|srcset)="([^"]+)"/g)) {
    const ref = m[1].split("#")[0].split("?")[0];
    if (!ref || /^(https?:|mailto:|data:)/.test(ref)) continue;
    const target = ref === "/" ? "index.html" : ref.replace(/^\//, "");
    if (!existsSync(join(root, target))) errors.push(`${page}: missing local file ${ref}`);
  }
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}
console.log(`ok: ${pages.length} pages checked`);
