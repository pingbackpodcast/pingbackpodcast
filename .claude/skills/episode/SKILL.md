---
name: episode
description: Draft, sync and publish a Pingback Podcast episode end to end (Descript → Buzzsprout, YouTube, pingbackpodcast.com). Use when Joel or Greg says "/episode N", "new episode", "episode N is on YouTube", or asks to add, sync or publish an episode.
---

# /episode N

One episode file (`_posts/YYYY-MM-DD-episode-N.md`) is the source of truth for
every platform. You draft it from the transcript; the hosts approve; the
scripts copy it to Buzzsprout and build the YouTube description.

**Never run `sync`, `publish`, `git push`, or anything that changes Buzzsprout
or YouTube without the host's explicit word in this conversation.** Drafting,
local files, local commits and the preview server are fine.

## 1. Gather (ask for anything missing, in one message)
- The YouTube video link (unlisted is fine) and the Descript project link.
- Guests: full names, how they want to be found (site, X, GitHub).
- Has the audio already gone to Buzzsprout from Descript? If so, its episode
  id (or check `bin/episode status N` once the id is in the file).

## 2. Scaffold and media
```bash
bin/episode new N --youtube <video link>        # writes the post with TODOs
bin/episode audio N --descript <project link>   # only if Buzzsprout doesn't have it yet:
                                                # renders audio in Descript, creates the
                                                # private Buzzsprout episode, uploads, records ids
bin/episode thumbnail N
```
Buzzsprout makes its transcript some minutes after the audio finishes
processing. Then:
```bash
bin/episode transcript N
```
If guests show up as "Speaker 03" etc., add `speaker_names:` to the front
matter (`"Speaker 03": "Jane Doe"`) and run it again.

## 3. Draft (you write; read the whole transcript first)
Replace every TODO in the post. House rules:
- **title**: sentence case, specific, no clickbait ("Sam Ruby on Roundhouse, Rails as a 4GL, and …").
- **description**: one or two plain sentences. Used on cards, SEO and the share card.
- **date**: the Buzzsprout release time in Pacific, `YYYY-MM-DD HH:MM:SS -0700`
  (Buzzsprout feed `pubDate`), so the site keeps the weekly schedule. Rename the
  file if the date changes.
- **topics**: slugs from `_data/topics.yml` only (rails, ai, indie, tools, other-tech).
- **guests**, **speaker_names** as needed.
- **chapters**: start from YouTube/Descript markers; tidy to sentence case;
  first at 0:00, ≥3 chapters, ≥10 s apart (YouTube's rules).
- **show notes** (the body): 2–4 short paragraphs of what's discussed, then
  `## Find <guest>` with their links. Fact-check names, titles and links; fix
  transcription slips (e.g. "Roudhouse" → Roundhouse).
- **moments**: 6–10, each `{ t, title, quote, topics }`. Quotes are the
  speaker's real words, lightly tidied (drop "uh", false starts), never invented.
  Times must match the transcript.
- No AI-sounding filler, no all-caps, no em-dash-heavy prose.

Then:
```bash
bin/og-cards N        # the Claude hook usually does this after edits; run it if unsure
bin/ci                # must say "CI passed."
bundle exec jekyll serve   # preview at http://localhost:4000/episodes/episode-N/
```
Commit locally (no push). Report: the preview URL, the title, anything you
weren't sure about (names, links, dates).

## 4. Review
Edit until the host approves. Re-run `bin/ci` after edits.

## 5. Sync (only when told "sync")
```bash
bin/episode sync N --dry-run   # show the host what will change
bin/episode sync N             # Buzzsprout: title, notes, tags, number, chapters
                               # (stays private); YouTube text goes to the clipboard
```
Tell the host to paste the clipboard into YouTube Studio (link printed) and Save.

## 6. Publish (only when told "publish" / "schedule for …")
```bash
bin/episode publish N                      # or --at "2026-10-30 23:00 -0700"
git push                                   # pre-push runs bin/ci; deploys the site
```
Remind the host to set the YouTube video to Public. Afterwards confirm with
`bin/episode status N` and `yt-dlp` that the chapters took, and report the
links and commit hashes.

## If something fails
Stop and say what failed; don't half-publish. Tokens come from 1Password
(vault "Pingback Podcast": item "Buzzsprout API", and the "Descript" item's
"website deploy API token" field); a
failed `op read` means the host needs to sign in to 1Password.
