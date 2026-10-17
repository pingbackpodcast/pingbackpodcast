# CLAUDE.md

Website for the **Pingback Podcast** — https://pingbackpodcast.com. Jekyll site on GitHub Pages, repo `pingbackpodcast/pingbackpodcast` (GitHub org, free plan; Joel is owner, co-host to be added as owner).

## How the site works
- **Theme:** Minima 3 (unreleased upstream), pulled from GitHub and pinned to a commit in `Gemfile`. Override a theme file by creating the same path locally (e.g. `_layouts/home.html`, `_includes/header.html`). Copies of upstream files are under `vendor/bundle/ruby/*/bundler/gems/minima-*/`.
- **Styles:** `_sass/minima/custom-styles.scss` (rules) and `_sass/minima/custom-variables.scss` (create it to override Minima's variables). Skin is `auto` (light/dark follows the OS), set in `_config.yml` under `minima:`.
- **Episodes are posts.** `_posts/YYYY-MM-DD-slug.md` → `/episodes/slug/`. `layout: episode` is applied automatically via `defaults` in `_config.yml`.
- **Static pages:** `about.md`, `episodes.md` (archive list), `index.md` (homepage, Minima `home` layout lists recent posts), `404.html`. Header nav order = `minima.nav_pages` in `_config.yml`.
- **Audio and podcast RSS live at the podcast host** (not chosen yet), not in this repo. The site only embeds the host's player. `feed.xml` (jekyll-feed) is a plain site feed, NOT the podcast feed — don't submit it to Apple/Spotify.
- **"Listen on" links:** `_data/platforms.yml`, rendered by `_includes/listen-links.html` on the homepage and every episode. Empty `url` = hidden.

## Episode front matter
```yaml
---
title: "Episode title"
episode: 12            # optional
season: 1              # optional
duration: "48:10"      # optional, free text
guests: ["Name One"]   # optional
embed_url: ""          # host's iframe player URL (preferred)
embed_height: 180      # optional, iframe height in px
audio_url: ""          # direct MP3 — used only when embed_url is empty
description: "One-line summary — used for SEO/social cards and the feed."
---
Show notes in Markdown.
```
`_posts/2026-10-16-hello-world.md` is a placeholder — delete it once real episodes are imported.

## Commands
```bash
bundle install                  # gems go to vendor/bundle (.bundle/config)
bundle exec jekyll serve        # http://localhost:4000, auto-rebuild
bundle exec jekyll build        # → _site/
```
Ruby version is in `.ruby-version` (mise). After a build, check output by grepping `_site/`.

## Deploy
Push to `main` → `.github/workflows/jekyll.yml` builds and deploys to Pages (Pages source = "GitHub Actions"). Check: `gh run list -L 3`. Pages status: `gh api repos/pingbackpodcast/pingbackpodcast/pages`.

## Domain / DNS
- `CNAME` file = `pingbackpodcast.com` (apex is canonical; GitHub redirects `www`).
- DNS is in Joel's Cloudflare account, all records **DNS only (grey cloud)** so GitHub can issue the HTTPS cert:
  - A `@` → 185.199.108.153, .109.153, .110.153, .111.153
  - AAAA `@` → 2606:50c0:8000::153, 8001::153, 8002::153, 8003::153
  - CNAME `www` → `pingbackpodcast.github.io`
  - TXT `_github-pages-challenge-pingbackpodcast` → org's verified-domain token
- No Cloudflare API token on this machine; DNS changes are made through the dashboard (Claude in Chrome).

## Rules
- Never add Claude attribution to commits (no Co-Authored-By, no generated-with trailers).
- Push only when the local build is clean.
