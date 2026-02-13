---
description: Cloudflare Worker proxy for Anthropic API
globs: "*.ts, *.toml, package.json"
alwaysApply: false
---

This is a Cloudflare Worker. Use `wrangler` for dev/deploy.

- Use `npm run dev` (wrangler dev) for local development
- Use `npm run deploy` (wrangler deploy) to publish
- Secrets: local dev uses `.dev.vars`, production uses `wrangler secret put`
- Types come from `@cloudflare/workers-types`
