---
name: pingback-deploy
description: Take a Pingback Podcast episode from an unlisted YouTube video (uploaded from Descript) to live on Buzzsprout, YouTube and pingbackpodcast.com. Use when Joel or Greg runs `pingback-deploy`, says "/pingback-deploy [N]", "new episode", "episode N is ready", or asks to add, sync or publish an episode.
---

# /pingback-deploy [N]

Started by the `pingback-deploy` terminal command (`bin/pingback-deploy`), or
typed in Claude Code.

**What the host does in Descript and YouTube before starting:** names the
speakers in Descript, uploads the video to YouTube as **unlisted**, sets the
**thumbnail** in YouTube Studio, and writes the **chapter timestamps** in the
YouTube description. Treat those as theirs: use their chapters and thumbnail
as they are (fix only obvious typos, and say so); don't make thumbnails.

**What you do:** everything else. One episode file
(`_posts/YYYY-MM-DD-episode-N.md`) is the source of truth for every platform.
You draft it; the host approves; the scripts copy it to Buzzsprout and build
the YouTube description.

**Never run `sync`, `publish`, `git push`, or anything that makes something
public, without the host's explicit word in this conversation.** Drafting,
local files, local commits, the preview server, private Buzzsprout episodes
and read-only API calls are fine. Episodes 1–3 are locked
(`buzzsprout_locked_through` in `_config.yml`); never try to change them.

## 0. Intake: ask once, up front
Work out the episode number: N if given, else one more than the highest
`episode:` in `_posts/`. Then ask everything in **one** go (AskUserQuestion for
the choices, plain questions for the rest):

1. **Episode number**: confirm the one you worked out.
2. **YouTube link** (unlisted is fine) and the **Descript project link**.
3. **Guests**: full names, links (site, X, GitHub, company). Or just Joel and Greg.
4. **Audio**: already on Buzzsprout, or should you send it?
5. **Release time**: default is one week after the previous episode's `date:`
   (Pacific). Offer that and "other".
6. Anything to mention in the notes (links, sponsors, corrections).

Don't ask for what you can read (duration, chapters, thumbnail, ids).

## 1. Scaffold and media
```bash
bin/episode new N --youtube <video link>   # post with the host's chapters, duration, youtube_id
bin/episode thumbnail N                    # the host's YouTube thumbnail, for the site
bin/episode audio N --descript <project link>   # only if Buzzsprout doesn't have it:
                                           # Descript renders the audio, a new PRIVATE
                                           # Buzzsprout episode gets it, ids recorded
```
If the thumbnail or chapters aren't on YouTube yet, say so and carry on; fetch
them again before step 3. Check the chapters meet YouTube's rules (first at
0:00, ≥3, ≥10 s apart) and tell the host if not: YouTube ignores them otherwise.

Transcript: Descript's export (`Pingback::Descript#export_transcript`), which
has the host's speaker names, or Buzzsprout's once it has processed the audio
(`bin/episode transcript N`). If someone comes out as "Speaker 03", add
`speaker_names:` and run it again.

Known gaps (fix them test-first the first time you hit them, then update this
file): there is no CLI for the Descript transcript export and its format is
unconfirmed (save the first real export, look at it, then write the parser
and tests); `bin/episode transcript` reads Buzzsprout's public transcript,
which may not exist while the episode is private (the API's
`high_fidelity_transcript` is the fallback); `bin/ci` fails on any
future-dated post, which blocks every push while a draft waits for its release
date, so give it a way to allow drafts (e.g. `bin/ci --future` for local
commits, strict on pre-push).

## 2. Draft (you write; read the whole transcript first)
Fill every TODO. House rules:
- **title**: sentence case, specific, no clickbait ("Sam Ruby on Roundhouse, Rails as a 4GL, and …").
- **description**: one or two plain sentences. Used on cards, SEO and the share card.
- **date**: the release time from intake, `YYYY-MM-DD HH:MM:SS -0700`; the
  filename date matches. The site post goes live by pushing at release (step 4).
- **topics**: slugs from `_data/topics.yml` only (rails, ai, indie, tools, other-tech).
- **guests**, **speaker_names** as needed.
- **chapters**: the host's, from YouTube.
- **show notes** (the body): 2–4 short paragraphs of what's discussed, then
  `## Find <guest>` with their links. Fact-check names, titles and links; fix
  transcription slips ("Roudhouse" → Roundhouse, "white coded" → vibe coded).
- **moments**: 6–10, each `{ t, title, quote, topics }`. Real words, lightly
  tidied (drop "uh", false starts), never invented. Times match the transcript.
- Plain writing: no AI-sounding filler, no all-caps, no em-dash-heavy prose.

Then:
```bash
bin/og-cards N        # the Claude hook usually does this after edits
bin/ci                # must say "CI passed." (see the future-date gap above)
bundle exec jekyll serve --port 4100 --future   # http://localhost:4100/episodes/episode-N/
```
Commit locally (no push). Report: preview URL, title, anything you weren't
sure about (names, links, dates). Edit until approved.

## 3. Sync (only when told "sync")
```bash
bin/episode sync N --dry-run   # show the host what will change
bin/episode sync N             # Buzzsprout: title, notes, tags, number, chapters
                               # (stays private); YouTube text goes to the clipboard
```
The YouTube text is the show notes plus the host's own chapters and links:
tell the host to paste it into the description in YouTube Studio (link
printed) and Save. Re-run `bin/episode thumbnail N` if they changed it.

## 4. Publish (only when told "publish" / "schedule for …")
```bash
bin/episode publish N                      # or --at "2026-10-30 23:00 -0700"
git push                                   # at release time; pre-push runs bin/ci
```
Remind the host to set the YouTube video to Public (or schedule it in Studio
for the same time). Afterwards confirm with `bin/episode status N` and
`yt-dlp` that the chapters took, check the live page, and report the links and
commit hashes.

## If something fails
Stop and say what failed; don't half-publish. Tokens come from 1Password
(vault "Pingback Podcast", item "Descript", fields "Buzzsprout API token" and
"Descript website deploy API token"); a failed `op read` means the host needs
to sign in to 1Password or approve the prompt.
