---
name: pingback-deploy
description: Take a Pingback Podcast episode from a finished Descript video to live on Buzzsprout, YouTube and pingbackpodcast.com. Use when Joel or Greg runs `pingback-deploy`, says "/pingback-deploy [N]", "new episode", "episode N is ready", or asks to add, sync or publish an episode.
---

# /pingback-deploy [N]

Started by the `pingback-deploy` terminal command (`bin/pingback-deploy`), or
typed in Claude Code. The host may have nothing but a finished video in
Descript: no notes, no transcript, no thumbnail. You do the rest, asking for
what you need.

One episode file (`_posts/YYYY-MM-DD-episode-N.md`) is the source of truth for
every platform. You draft it; the host approves; the scripts copy it to
Buzzsprout and build the YouTube description.

**Never run `sync`, `publish`, `git push`, or anything that makes something
public, without the host's explicit word in this conversation.** Drafting,
local files, local commits, the preview server, private Buzzsprout episodes
and read-only API calls are fine. Episodes 1–3 are locked
(`buzzsprout_locked_through` in `_config.yml`); never try to change them.

## 0. Intake: ask once, up front
Work out the episode number first: N if given, else one more than the highest
`episode:` in `_posts/`. Read `docs/thumbnail-style.md`. Then ask everything in
**one** go (AskUserQuestion for the choices, plain questions for the rest):

1. **Episode number**: confirm the one you worked out.
2. **Descript project link** (the address bar URL of the project).
3. **Who's on it**: just Joel and Greg, or guests? For each guest: full name,
   how to say their name if unusual, links (site, X, GitHub, company).
4. **Where things are now**: is the video on YouTube yet (link; unlisted is
   fine)? Has the audio gone to Buzzsprout yet?
5. **Release time**: default is one week after the previous episode's `date:`
   (Pacific). Offer that and "other".
6. **Thumbnail**: anything specific this time (a frame or moment they like, a
   word or name to feature)? Use the saved preferences otherwise.
7. Anything to mention in the notes (links, sponsors, corrections).

Don't ask for what you can find (durations, chapters, existing ids).

## 1. Media and transcript
Audio to Buzzsprout, if it isn't there yet (creates a **private** episode):
```bash
bin/episode audio N --descript <project link>
```
Transcript: prefer Descript's own export (it has the host's markers, which
become chapters): `Pingback::Descript#export_transcript` in
`lib/pingback/descript.rb`. Otherwise Buzzsprout's, once it has processed the
audio: `bin/episode transcript N`. If guests come out as "Speaker 03", add
`speaker_names:` and run it again.

Known gaps (fix them test-first the first time you hit them, then update this
file): `bin/episode new` needs a YouTube link, so without one write the post
by hand from the template in CLAUDE.md and add `youtube_id` later; there is no
CLI for the Descript transcript export, and its marker format is unconfirmed
(save the first real export, look at it, then write the parser and tests);
`bin/episode transcript` reads Buzzsprout's public transcript, which may not
exist while the episode is private (the API's `high_fidelity_transcript` is
the fallback); `bin/ci` fails on any future-dated post, which blocks every
push (not just this episode's) while a draft waits for its release date, so
give it a way to allow drafts (e.g. `bin/ci --future` for local commits, strict
on pre-push).

Once the video is on YouTube: put `youtube_id` in the post, then
`bin/episode thumbnail N` only if the host made their own thumbnail;
otherwise see step 3.

## 2. Draft (you write; read the whole transcript first)
Fill the post. House rules:
- **title**: sentence case, specific, no clickbait ("Sam Ruby on Roundhouse, Rails as a 4GL, and …").
- **description**: one or two plain sentences. Used on cards, SEO and the share card.
- **date**: the release time from intake, `YYYY-MM-DD HH:MM:SS -0700`. The
  filename date matches. The site post goes live by pushing at release time
  (step 6).
- **duration**: "NN min".
- **topics**: slugs from `_data/topics.yml` only (rails, ai, indie, tools, other-tech).
- **guests**, **speaker_names** as needed.
- **chapters**: from Descript markers or the transcript; sentence case; first
  at 0:00, ≥3, ≥10 s apart (YouTube's rules).
- **show notes** (the body): 2–4 short paragraphs of what's discussed, then
  `## Find <guest>` with their links. Fact-check names, titles and links; fix
  transcription slips ("Roudhouse" → Roundhouse, "white coded" → vibe coded).
- **moments**: 6–10, each `{ t, title, quote, topics }`. Real words, lightly
  tidied (drop "uh", false starts), never invented. Times match the transcript.
- Plain writing: no AI-sounding filler, no all-caps, no em-dash-heavy prose.

## 3. Thumbnail (the host is picky: offer options, iterate)
Follow `docs/thumbnail-style.md`. Make **2–3 options** at 1280×720: pull
frames from the video (`yt-dlp` once it's on YouTube, or a Descript export),
pick ones where faces look good, compose them in HTML/CSS and render with
headless Chromium + ImageMagick (as `bin/og-cards` does). Show them, take
notes, revise. When one is picked, save it as
`assets/images/episodes/episode-N.jpg`, tell the host to upload it in YouTube
Studio, and **add anything new you learned about their taste to
`docs/thumbnail-style.md`**.

## 4. Check and preview
```bash
bin/og-cards N        # the Claude hook usually does this after edits
bin/ci                # must say "CI passed." (see the future-date gap above)
bundle exec jekyll serve --port 4100 --future   # http://localhost:4100/episodes/episode-N/
```
Commit locally (no push). Report: preview URL, title, thumbnail options, and
anything you weren't sure about (names, links, dates). Edit until approved.

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
