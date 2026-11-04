# outskirts site

outskirts.dev, served by a Cloudflare Worker with Static Assets only (no script): the home page lives in `public/`, the documentation pages are built from the Markdown of `../docs/` and `../CHANGELOG.md`.

- `npm install` once, then `npm run build` writes `public/docs/` and `public/sitemap.xml` (generated, not committed).
- `npm run sync` regenerates `../docs/options.md` from `../outskirts.schema.json` and the README extracts between `<!-- docs:begin page#anchor -->` and `<!-- docs:end -->`.
- `npm run check` builds, then checks the generated Markdown, the HTML metadata, links and anchors, code line length, the navigation, the sitemap and the colors of `style.css`.
- `npm run deploy` runs `wrangler deploy`, whose build step runs `npm run build`; add `-- --dry-run` to preview.
- No route or custom domain is configured here: the domain is attached by the owner.
