# outskirts site

One-page site served by a Cloudflare Worker with Static Assets only (no script); content lives in `public/`.

- `npm install && npm run check` validates the HTML references and the required metadata.
- `npm run deploy` runs `wrangler deploy`; add `-- --dry-run` to preview.
- No route or custom domain is configured here: the domain is attached by the owner.
