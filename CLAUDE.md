# CLAUDE.md

Website for the **Pingback Podcast** — https://pingbackpodcast.com. Jekyll site on GitHub Pages, repo `pingbackpodcast/pingbackpodcast` (GitHub org, free plan; Joel is owner, co-host to be added as owner).

## How the site works
- **Theme:** Minima 3 (unreleased upstream) is pinned to a commit in `Gemfile`, but it only supplies plugin wiring; even `_includes/head.html` is ours. **All visuals are ours:** layouts in `_layouts/` (base, home, page, episode), includes in `_includes/` (header, footer, episode-list, listen-links, custom-head for fonts), and the entire stylesheet in `assets/css/style.scss`, which replaces Minima's CSS.
- **Design:** cool paper `#f2f4f7`, navy ink `#15192b`, cobalt accent `#2f4fe0`. Dark mode follows the OS and uses a deep navy, not near-black. One typeface, Archivo (Google Fonts, variable): the wide cut (`wdth 125`) for headings and the normal cut for body. The single flourish is the cobalt full stop after the homepage wordmark, which pings on load (off under reduced motion). Keep it simple: no all-caps labels, mono tags, cards with shadows, gradients, or decorative arrows.
- **Episodes are posts.** `_posts/YYYY-MM-DD-episode-N.md` → `/episodes/episode-N/`. `layout: episode` is applied automatically via `defaults` in `_config.yml`.
- **Static pages:** `about.md`, `episodes.md` (full list), `index.md` (homepage intro text; the layout adds the wordmark and episode list), `404.html`. Header nav order = `minima.nav_pages` in `_config.yml`. Hosts (name, link, photo, role) live in `hosts:` in `_config.yml`: linked in the footer and shown with photos and captions on About via `_includes/hosts.html`. Photos are in `assets/images/hosts/` (taken from greg.molnar.io and joelgaff.com).
- **Audio and podcast RSS live at Buzzsprout**, not in this repo. Set `buzzsprout_podcast_id` in `_config.yml` and `buzzsprout_id` on each episode to show the Buzzsprout player. The podcast feed is `https://rss.buzzsprout.com/2443886.rss` (`podcast_feed` in `_config.yml`, advertised in `<head>`). Minima still makes an unlinked `feed.xml` (a plain site feed). Never submit that one anywhere.
- **Video:** every episode is also on YouTube (https://www.youtube.com/@PingbackPodcast). `youtube_id` embeds it (privacy-enhanced youtube-nocookie domain), and chapter timestamps link into the video.
- **"Listen on" links:** `_data/platforms.yml`, rendered by `_includes/listen-links.html` on the homepage and in the footer elsewhere. Empty `url` = hidden.

## SEO
- jekyll-seo-tag builds the title, description, canonical URL, Open Graph and Twitter tags. Home title = `title | tagline`; other pages = `page title | site title`. Give every page a `description`.
- Share cards (X / Open Graph) are 1200x630 PNGs in `assets/images/og/`, card type `summary_large_image`. `default.png` covers every page via `defaults`; each episode has `image: /assets/images/og/episode-N.png`. **Cards are automatic:** a Claude Code hook (`.claude/settings.json` → `bin/og-cards-hook`) runs `bin/og-cards N` after any Write/Edit to an episode in `_posts/`, rendering the card and adding the `image:` block. Commit the new `assets/images/og/episode-N.png` with the episode. Editing outside Claude? Run `bin/og-cards N` yourself (`bin/og-cards` alone re-renders all). Check a card with the X post composer or opengraph.xyz after deploying.
- Structured data: episodes are typed `PodcastEpisode` (via `seo.type` in defaults); the homepage adds a `PodcastSeries` block (`_includes/podcast-series-ld.html`) with hosts, feed, and `social.links`.
- `jekyll-sitemap` makes `/sitemap.xml`; `robots.txt` points to it; `404.html` is left out of the sitemap.
- Homepage H1 is "Pingback Podcast" (big wordmark + smaller "Podcast" line).

## Episode front matter
```yaml
---
title: "Episode title"            # sentence case
episode: 3
duration: "48 min"
guests: ["Name One"]              # optional
description: "One or two sentences — shown in the episode list and used for SEO/social cards."
youtube_id: abc123XYZ             # the v= value of the YouTube video
buzzsprout_id: 12345678           # Buzzsprout episode ID (player shows once buzzsprout_podcast_id is set)
embed_url: ""                     # alternative: any host's iframe player URL
audio_url: ""                     # alternative: direct MP3 (used only if nothing above is set)
chapters:                         # optional; "m:ss" or "h:mm:ss"
  - { t: "0:00", title: "Welcome" }
---
Show notes in Markdown. Use "## Heading" for sections such as links for the guest.
```
**Importing from YouTube:** `yt-dlp --skip-download --write-info-json -o ID "https://www.youtube.com/watch?v=ID"` gives the title, `upload_date`, `duration_string`, description, and chapters. For the post date, use the Buzzsprout `pubDate` from the RSS feed converted to Pacific time (`date: YYYY-MM-DD HH:MM:SS -0700`), since YouTube upload dates are UTC and can land a day late. The Buzzsprout episode ID is the number in the feed item's `<guid>Buzzsprout-NNNN</guid>`. Jekyll skips future-dated posts.

## Commands
```bash
bin/setup                       # first time: gems + enable the pre-push guard
bin/ci                          # the same checks the pre-push hook runs
bundle exec jekyll serve        # http://localhost:4000, auto-rebuild
bundle exec jekyll build        # → _site/
```
Ruby version is in `.ruby-version` (mise). After a build, check output by grepping `_site/`.

## Local CI (pre-push)
`.githooks/pre-push` runs `bin/ci` before every push and blocks it if anything fails (a push to `main` deploys). `bin/ci` takes about a second and checks: production build with strict front matter (no errors/warnings), required episode front matter, each episode's share card exists **and is committed**, no future-dated episodes (Jekyll silently skips them), and every internal link/image resolves. Fresh clone: run `bin/setup` (installs gems, sets `core.hooksPath`). Emergency bypass: `git push --no-verify`.

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
