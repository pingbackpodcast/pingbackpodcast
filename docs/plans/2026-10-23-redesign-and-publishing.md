# Pingback redesign + one-command publishing — plan

Status: **plan only, nothing built yet.** Written 2026-10-23.

## Context

Joel wants pingbackpodcast.com to have what he likes about the Not Brothers site
(heyoodle.com/not-brothers): card layouts everywhere, an episode page with a
video, chapters, "best moments" cards, show notes and a searchable full
transcript, and the same hover feel. He also wants publishing to be one (or a
few small) actions: record in Descript, and have YouTube, Buzzsprout and the
website all get the same notes, chapters and transcript.

Decisions already made:
- **Look:** their layout and interactions, **Pingback's brand** (logo colours, our
  type). Not a clone: no pill eyebrow above every section, no condensed all-caps.
- **Scope:** episode page rebuild, best moments, homepage + episodes grid, topics
  + start here, and the publishing pipeline.
- **Media:** Descript uploads the video to YouTube (manual export). Audio goes to
  Buzzsprout through the APIs (Descript publish → Buzzsprout upload).
- **YouTube:** no Google Cloud project. We read with `yt-dlp`; the description is
  pasted by hand (the pipeline copies it to the clipboard).
- **Secrets:** 1Password, read with `op` at run time. Nothing on disk or in git.
- **Drafting:** Claude drafts via a `/episode` command; Underlord can be used as
  an input. Nothing syncs or publishes without Joel saying so.

## What we're copying from Not Brothers

- **Cards:** rounded panels, 1px border, slightly lighter surface than the page.
- **Hover (≈120ms ease):** border and title shift to the accent; thumbnails scale
  ~1.03; chips and buttons lift 1px with a soft accent glow. Keyboard focus gets
  the same treatment; `prefers-reduced-motion` turns movement off.
- **Episode page order:** header (episode, date, length, title, summary, topics) →
  video → best moments grid → show notes with sticky chapters column → full
  transcript (speaker, timestamp, search).
- **Click-to-seek:** chapters, moments and transcript lines jump the video on the
  same page.
- **Homepage:** hero with the cover art in a framed card, latest episode as a large
  card, "start here" picks, topic cards with counts, listen tiles with icons, a
  fuller footer.
- **Episodes page:** card grid with thumbnails, topic filters.

## Design system (Pingback brand)

Dark-first, drawn from the cover art (sampled `#181a26` background):

| Token | Value (starting point) | Use |
|---|---|---|
| `--bg` | `#14161f` | page |
| `--surface` | `#1c1f2c` | cards |
| `--line` | `#2b2f44` | card borders, rules |
| `--ink` | `#e8ebf5` | text |
| `--muted` | `#9aa3bd` | meta, secondary |
| `--ruby` | `#e8436b` (from the gem) | primary accent: hover, buttons, play |
| `--sky` | `#7cc8ff` (from the arcs) | secondary accent: timestamps, links |
| `--gold` | `#e0b060` (from "& more") | sparing highlight |

- **Type:** Archivo stays (wide cut for headings, normal for body). JetBrains Mono
  only for timestamps and the terminal-prompt flourish, because the logo is
  terminal-styled.
- **Dark only** (decided): no light mode. The current cobalt site goes away.
- **Keep from today:** the pinging dot (recoloured ruby), single-column reading width
  for prose, sentence case, no decorative arrows, no all-caps labels.

## Pages

### Episode page (`_layouts/episode.html`, rebuilt)
1. Header: "Episode N" chip, date, length, title, summary, topic chips, guests.
2. Video (YouTube IFrame API on youtube-nocookie, loaded on first click so the page
   stays light). Buzzsprout player below as "listen instead".
3. **Best moments:** 2-column grid of cards: generated art, topic chips, title,
   quote, "Play from 12:34" (seeks the video).
4. **Show notes + chapters:** prose on the left; chapters on the right, sticky on
   desktop, inline on mobile. Clicking a chapter seeks. The current chapter
   highlights while the video plays.
5. **Full transcript:** speaker-name + timestamp turns, a search box that filters
   and highlights matches, clicking a timestamp seeks. Optional follow-along
   highlight of the current turn.
6. Next/previous episode cards.

### Homepage
Hero (wordmark, pitch, Play the latest / Start here / Follow) beside the cover art
card → latest episode feature card (thumbnail, chips, title, summary, Play) →
start-here row (3 picks) → topics grid with counts → listen tiles (icon,
platform type, name) → footer (about, explore links, listen icons, hosts).

### Episodes page
Card grid (thumbnail, episode chip, date, title, two-line summary, topics). Topic
filter chips filter in place with JS and link to topic pages without it.

### Topics + start here
- `/topics/` index and `/topics/<slug>/` pages (episode cards filtered by topic).
- Start-here picks curated in `_data/start_here.yml`. **Hidden until ~6 episodes**
  (decided); the row renders only when the file has entries. Remind Joel at episode 6.

### About
Restyled into the card system; content unchanged.

## Data model

Episode front matter grows (one file is the source of truth for every platform):

```yaml
episode: 4
title: "…"
description: "…"                # list cards, SEO, Buzzsprout summary
duration: "52 min"
date: 2026-10-30 23:00:00 -0700
guests: [{ name: "…", url: "…" }]
topics: [rails, ai]             # slugs from _data/topics.yml
youtube_id: …
buzzsprout_id: …
descript_project: …             # Descript project id (+ composition id)
chapters: [{ t: "0:00", title: "…" }]
moments:                        # best moments
  - { t: "12:34", title: "…", quote: "…", topics: [ai] }
image: { path: /assets/images/og/episode-4.png, … }
```

- `_data/transcripts/episode-N.json`: `[{ "speaker": "Greg", "t": 83.2, "text": "…" }]`
  grouped into speaker turns (not words), so pages stay small.
- `_data/topics.yml`: `slug`, `name`, one-line blurb.
- `_data/start_here.yml`: `episode`, label ("Best Rails episode"), one-liner.
- Thumbnails: YouTube `maxresdefault` saved to `assets/images/episodes/episode-N.jpg`
  (no hotlinking).
- Moment art: `bin/og-cards` gains a portrait moment-card template (cover art +
  moment title), output `assets/images/moments/episode-N-M.png`.

Back catalogue (episodes 1–3): transcripts and chapters come from Buzzsprout's
public `transcript.json` / `chapters.json` (speaker names are already correct);
thumbnails from YouTube; moments and topics drafted by Claude for Joel to approve.

## Publishing pipeline

### Commands (`bin/episode`, Ruby stdlib only)
- `bin/episode draft N <descript-project-url> [--youtube URL]`
  - Descript API: export the transcript (`include_speaker_labels`, `include_markers`,
    `timecodes`) → transcript data + chapters from markers.
  - Optional Underlord job ("suggest show notes and 8 best moments with
    timestamps") → saved as input for drafting.
  - Writes/updates `_posts/…-episode-N.md` with everything known; leaves
    `TODO` markers for Claude/Joel.
  - If `--youtube` is given: `yt-dlp` for the thumbnail and to confirm chapters.
- `bin/episode sync N`
  - **Buzzsprout:** creates the private episode if missing. Descript publishes the
    audio and returns a download URL; we upload it with Buzzsprout's upload API.
    Sets title, HTML description (show notes + links), episode number and tags.
    Replaces the chapters. Once Buzzsprout's transcript exists, fixes speaker labels.
  - **Website:** writes transcript data, thumbnails, share card, moment cards.
  - **YouTube:** builds the description (notes + `0:00` chapter list + links) and
    copies it with `wl-copy`; prints the Studio URL.
  - Idempotent: safe to rerun after any edit.
- `bin/episode publish N [--at "2026-10-30 23:00"]`
  - Buzzsprout `private: false` (or scheduled `published_at`).
  - Commits and pushes the site (pre-push `bin/ci` runs).
  - Reminds Joel to flip YouTube to public; then re-reads it with `yt-dlp` to
    confirm the chapters took.
- `bin/episode status N`: what each platform has and what's missing.

### Code layout
`lib/pingback/` with `descript.rb`, `buzzsprout.rb`, `secrets.rb` (`op read`),
`transcript.rb` (word/turn grouping, Descript and Buzzsprout parsers),
`episode_file.rb` (front matter read/write without reformatting), `youtube_text.rb`.

### `/episode` command (`.claude/skills/episode/SKILL.md`)
1. Run `bin/episode draft`.
2. Ask what can't be inferred (guest name and links, topics).
3. Read the transcript and write title, description, notes, chapters (from markers,
   refined), 6–10 moments with quotes, topics.
4. Render cards, run `bin/ci`, start the local server, report the draft URL plus
   anything uncertain.
5. Edit until Joel approves. **`sync` and `publish` only on his explicit word.**

### Secrets
1Password vault **`Pingback Podcast`** (Joel's; not shared yet, so only Joel can sync/publish until Greg is added):
`Pingback – Buzzsprout API` and `Pingback – Descript API`, field `credential`.
Scripts call `op read op://<vault>/<item>/credential`; fail with a clear message
if `op` isn't signed in.

## Phases

Each phase: tests first (red, then green), local commits, show commit list, **no
push until Joel says "push"**. `bin/ci` grows with each phase.

| # | Phase | Done when |
|---|---|---|
| 0 | **Joel's prep:** Buzzsprout + Descript tokens into the `Pingback Podcast` vault; confirm the Descript plan includes API access (needed by phase 6 only) | `op read` works for both |
| 1 | **Design system:** tokens, card/chip/button components, hover + focus + reduced motion; restyle existing pages | Screenshots desktop + phone |
| 2 | **Episode page:** new layout, chapters with seek, transcript with search + seek; backfill eps 1–3 from Buzzsprout | All 3 episodes show transcript and chapters; clicking seeks the video |
| 3 | **Best moments:** front matter, moment-card art, grid; draft moments for eps 1–3 | Joel approves the moments |
| 4 | **Homepage + episodes grid:** hero, latest card, thumbnails, listen tiles with icons, footer | Screenshots reviewed |
| 5 | **Topics + start here:** data files, topic pages, filters | Joel picks topics and start-here episodes |
| 6 | **Pipeline scripts:** Descript + Buzzsprout clients, `draft` / `sync` / `publish` / `status`, tested with recorded fixtures (no network in tests) | Dry run against episode 3 changes nothing unexpected |
| 7 | **`/episode` command + docs:** skill file, CLAUDE.md update; first real run on the next episode | Episode 4 published end-to-end |

New `bin/ci` checks: every episode has transcript data, chapters are ordered and
inside the duration, moment times are inside the duration, topic slugs exist,
thumbnails and moment cards are committed.

## Risks and checks

- **Timeline alignment:** Descript, YouTube and Buzzsprout should share one
  timeline. Episode 3's chapters match on YouTube and Buzzsprout. Verify per
  episode before trusting seek times; `bin/ci` can't check this, so `sync` prints
  a spot check.
- **Descript API plan/credits:** imports use media minutes and Underlord uses AI
  credits; a 402 means the plan is out.
- **Unlisted YouTube videos** don't appear in channel listings, so `draft` needs the
  video URL (from Descript's export) until it's public.
- **Buzzsprout transcript timing:** generated after audio processing, so speaker-label
  fixes may need a second `sync`.
- **Page weight:** a ~10k-word transcript is about 80–120 KB of HTML; fine, and the
  video loads only on click.
- **YouTube description** stays a manual paste (by choice, no Google Cloud).

## Decisions (answered 2026-10-23)

1. **Topics:** Rails & Ruby (`rails`), AI & agents (`ai`), Indie & business (`indie`),
   Tools & setup (`tools`), Other tech (`other-tech`).
2. **Start here:** hidden until about six episodes exist.
3. **Theme:** dark only.
4. **Underlord clips:** not yet; revisit once the pipeline runs smoothly.
5. **1Password:** existing `Pingback Podcast` vault; share with Greg later.

Still open: Joel to confirm the Descript plan includes API access (blocks phase 6 only).
