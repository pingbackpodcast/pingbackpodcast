# CLAUDE.md

Website for the **Pingback Podcast** — https://pingbackpodcast.com. Jekyll site on GitHub Pages, repo `pingbackpodcast/pingbackpodcast` (GitHub org, free plan; Joel is owner, co-host to be added as owner).

## How the site works
- **Theme:** Minima 3 is pinned in `Gemfile` but only supplies plugin wiring. **All visuals are ours:** `_layouts/` (base, home, page, episode, topic), `_includes/` (header, footer, episode-list, topic-cards, listen-tiles, start-here, hosts, icons/, head, custom-head), `assets/css/style.scss` (the whole stylesheet), `assets/js/episode.js` and `topics.js`.
- **Design (dark only, from the cover art):** tokens on `:root`: `--bg #14161f`, `--surface #1c1f2c`, `--line #2b2f44`, `--ink #e8ebf5`, `--muted #9aa3bd`, `--ruby #e8436b` (accent; `--ruby-text` for text), `--sky #7cc8ff` (timestamps), `--gold #e0b060` (speaker names). Archivo (wide cut for headings) + JetBrains Mono for timestamps only. Components: `.card` (hover/focus: ruby border + title), `.chip` (`a.chip` lifts 1px with a glow), `.btn--primary` / `.btn--ghost`, listen tiles. Motion ~120ms; reduced motion turns it off; the homepage ping dot is the one flourish. Layout and hover feel follow heyoodle.com/not-brothers, in Pingback's brand: no all-caps eyebrows or gradients. Plan: `docs/plans/2026-10-23-redesign-and-publishing.md`.
- **Episodes are posts:** `_posts/YYYY-MM-DD-episode-N.md` → `/episodes/episode-N/` (`layout: episode` via defaults). The page: header (chips, title, summary, topics) → click-to-load YouTube (local thumbnail facade) → Buzzsprout "Listen instead" → best moments → show notes beside sticky chapters → full transcript (speaker, timestamp, search) → previous/next. Anything with `data-seek` (chapters, moments, transcript times) jumps the video; each also has a YouTube `&t=` fallback link.
- **Episode data outside the post:** transcript `_data/transcripts/episode-N.json` (speaker turns, from Buzzsprout), thumbnail `assets/images/episodes/episode-N.jpg`, moment art `assets/images/moments/episode-N-M.jpg`, share card `assets/images/og/episode-N.png`.
- **Topics:** `_data/topics.yml` (slug, name, blurb). `_plugins/topic_pages.rb` makes `/topics/<slug>/`; `topics.md` is the index; the Episodes page filters in place. **Start here:** `_data/start_here.yml`, hidden while empty (fill it around episode 6).
- **Static pages:** `index.md` (homepage pitch; `home` layout adds hero, latest card, earlier episodes, topics, listen tiles), `episodes.md`, `topics.md`, `about.md`, `404.html`. Nav order = `minima.nav_pages`. Hosts (name, url, photo, role) in `hosts:` in `_config.yml`.
- **Speaker names:** `speakers:` in `_config.yml` maps Buzzsprout labels to names; guests go in each post's `speaker_names:`.
- **Audio and podcast RSS live at Buzzsprout** (`buzzsprout_podcast_id` in `_config.yml`, `buzzsprout_id` per episode). Feed: `https://rss.buzzsprout.com/2443886.rss` (`podcast_feed`, advertised in `<head>`). Minima's unlinked `feed.xml` is not the podcast feed.
- **Video:** YouTube (https://www.youtube.com/@PingbackPodcast), `youtube_id` per episode.
- **Listen/follow links:** `_data/platforms.yml` (name, kind, icon, url; empty url hides it) → homepage tiles and footer icons. Icons in `_includes/icons/` are from Simple Icons (CC0).
- `_plugins/time_filters.rb` adds Liquid `seconds` ("1:59" → 119) and `clock` (119 → "1:59").

## Analytics
- **Site visits:** Cloudflare Web Analytics (cookieless), site set to "JS snippet" mode because DNS is grey-cloud. Snippet is in `_includes/head.html`, production builds only; token in `_config.yml` (`cloudflare_analytics_token`). Dashboard: Cloudflare → Analytics & Logs → Web Analytics → pingbackpodcast.com.
- **Downloads** (the number sponsors care about most) come from Buzzsprout's stats; video views from YouTube Studio.

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
date: 2026-10-16 23:00:00 -0700   # Buzzsprout release time, Pacific
episode: 3
topics: [rails, ai]               # slugs from _data/topics.yml (required)
duration: "54 min"
guests: ["Sam Ruby"]
speaker_names: { "Speaker 03": "Jane Doe" }   # only if Buzzsprout didn't name someone
youtube_id: yW4oRzt9AqE
buzzsprout_id: 19975498
descript_project: "https://web.descript.com/…"   # set by bin/episode audio
description: "One or two sentences: cards, SEO, share card."
chapters:                         # "m:ss" / "h:mm:ss"; YouTube needs 0:00 first, ≥3, ≥10 s apart
  - { t: "0:00", title: "Welcome" }
moments:                          # 6–10 best moments; real quotes, lightly tidied
  - { t: "2:46", title: "…", quote: "…", topics: [rails] }
image: { path: /assets/images/og/episode-3.png, … }   # added by bin/og-cards
---
Show notes in Markdown (2–4 paragraphs, then "## Find <guest>" links).
```

## Commands
```bash
bin/setup                       # first time: gems + enable the pre-push guard
bin/test                        # Minitest suite (builds the site once, asserts on HTML/CSS, unit tests)
bin/ci                          # build + content checks + bin/test (what pre-push runs)
bundle exec jekyll serve        # http://localhost:4000 (restart after _config.yml changes)
bin/og-cards [N]                # share card + moment art (the Claude hook runs this after post edits)
bin/episode …                   # episode pipeline, see below and `bin/episode` with no args
```
Ruby version in `.ruby-version` (mise). Work test-first: write the failing test, see it fail, then make it pass. Tests never touch the network (fake HTTP in `test/buzzsprout_test.rb`).

## Publishing an episode
Run **`pingback-deploy [N]`** in any terminal (`bin/pingback-deploy`, symlinked into `~/.local/bin`), or **`/pingback-deploy [N]`** in Claude Code (`.claude/skills/pingback-deploy/SKILL.md`). It asks for what it needs (YouTube and Descript links, guests, release time) and walks the whole flow. The hosts name speakers in Descript, upload to YouTube unlisted, and set the thumbnail and chapter timestamps in YouTube themselves; the pipeline reads both from the video. Episodes 1–3 are locked against Buzzsprout changes (`buzzsprout_locked_through`). The pieces:
`bin/episode new N --youtube URL` (scaffold from YouTube) → `audio N --descript LINK` (Descript renders audio → private Buzzsprout episode + upload) → `transcript N` / `thumbnail N` → Claude drafts the post (no TODOs left; `bin/ci` blocks them) → `sync N [--dry-run]` (Buzzsprout title/notes/tags/number/chapters; YouTube description to the clipboard, pasted by hand: there is deliberately no Google Cloud project) → `publish N [--at TIME]` → `git push`. **Sync, publish and push only on a host's explicit word.**
Tokens: 1Password vault "Pingback Podcast", item "Descript", fields `Buzzsprout API token` and `Descript website deploy API token`, or `PINGBACK_BUZZSPROUT_TOKEN` / `PINGBACK_DESCRIPT_TOKEN`; requested only when an API call is about to run.
Not done yet: drafting from Descript's own transcript export (markers → chapters) needs one real export to pin the format; until then transcripts come from Buzzsprout.

## Local CI (pre-push)
`.githooks/pre-push` runs `bin/ci` before every push and blocks it if anything fails (a push to `main` deploys). `bin/ci` takes a few seconds and checks: production build (strict front matter, no warnings); required episode front matter incl. topics; no TODOs; share card and moment art exist **and are committed**; chapters ordered; chapter/moment times inside the episode; known topic slugs; no future-dated episodes; every internal link/image resolves; and the full `bin/test` suite. `bin`, `lib`, `test`, `docs` are excluded from the published site (a test guards it). Fresh clone: run `bin/setup` (installs gems, sets `core.hooksPath`). Emergency bypass: `git push --no-verify`.

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
