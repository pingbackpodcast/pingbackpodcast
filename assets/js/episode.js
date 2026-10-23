// Episode page: click-to-load YouTube, seek from chapters/moments/transcript,
// transcript search, and "now playing" highlights. No dependencies.
(() => {
  "use strict";

  const video = document.querySelector(".episode-video[data-youtube-id]");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let player = null;
  let ready = null; // Promise resolved with the YT.Player once it can seek

  // --- YouTube ------------------------------------------------------------

  function loadApi() {
    if (window.YT && window.YT.Player) return Promise.resolve();
    return new Promise((resolve) => {
      const previous = window.onYouTubeIframeAPIReady;
      window.onYouTubeIframeAPIReady = () => { previous && previous(); resolve(); };
      const tag = document.createElement("script");
      tag.src = "https://www.youtube.com/iframe_api";
      document.head.append(tag);
    });
  }

  function startPlayer(startSeconds) {
    if (ready) return ready;
    const mount = document.createElement("div");
    video.replaceChildren(mount);
    ready = loadApi().then(() => new Promise((resolve) => {
      player = new window.YT.Player(mount, {
        host: "https://www.youtube-nocookie.com",
        videoId: video.dataset.youtubeId,
        playerVars: { autoplay: 1, start: Math.floor(startSeconds || 0), rel: 0, playsinline: 1 },
        events: {
          onReady: () => { player.playVideo(); resolve(player); },
          onStateChange: (e) => (e.data === window.YT.PlayerState.PLAYING ? watch() : unwatch()),
        },
      });
    }));
    return ready;
  }

  function seek(seconds) {
    if (!video) return false;
    video.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "center" });
    if (!ready) { startPlayer(seconds); return true; }
    ready.then((p) => { p.seekTo(seconds, true); p.playVideo(); });
    return true;
  }

  if (video) {
    video.querySelector(".video-facade")?.addEventListener("click", () => startPlayer(0));

    // Chapters, moments and transcript timestamps all carry data-seek and a
    // YouTube fallback href, so they still work without this script.
    document.addEventListener("click", (event) => {
      const link = event.target.closest("[data-seek]");
      if (!link || event.metaKey || event.ctrlKey || event.shiftKey) return;
      if (seek(Number(link.dataset.seek))) event.preventDefault();
    });
  }

  // --- "Now playing" highlights ---------------------------------------------

  const chapters = [...document.querySelectorAll(".chapters li[data-start]")];
  const turns = [...document.querySelectorAll(".turn[data-start]")];
  let timer = null;

  function current(items, t) {
    let found = null;
    for (const item of items) {
      if (Number(item.dataset.start) <= t) found = item; else break;
    }
    return found;
  }

  function mark(items, active, attr) {
    for (const item of items) {
      if (item === active) item.setAttribute(attr, attr === "aria-current" ? "true" : "");
      else item.removeAttribute(attr);
    }
  }

  function tick() {
    if (!player || typeof player.getCurrentTime !== "function") return;
    const t = player.getCurrentTime();
    mark(chapters, current(chapters, t), "aria-current");
    mark(turns, current(turns, t), "data-playing");
  }

  function watch() { if (!timer) timer = setInterval(tick, 1000); tick(); }
  function unwatch() { clearInterval(timer); timer = null; }

  // --- Transcript search ----------------------------------------------------

  const search = document.getElementById("transcript-search");
  if (search) {
    const count = document.querySelector(".transcript__count");
    const empty = document.querySelector(".transcript__empty");
    const texts = turns.map((turn) => {
      const el = turn.querySelector(".turn__text");
      return { turn, el, text: el.textContent, lower: el.textContent.toLowerCase() };
    });

    const escapeRegExp = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    function highlight(el, text, query) {
      el.replaceChildren();
      const parts = text.split(new RegExp(`(${escapeRegExp(query)})`, "ig"));
      for (const part of parts) {
        if (part.toLowerCase() === query) {
          const m = document.createElement("mark");
          m.textContent = part;
          el.append(m);
        } else if (part) {
          el.append(part);
        }
      }
    }

    let pending = null;
    search.addEventListener("input", () => {
      clearTimeout(pending);
      pending = setTimeout(() => {
        const query = search.value.trim().toLowerCase();
        let shown = 0;
        for (const { turn, el, text, lower } of texts) {
          const hit = !query || lower.includes(query);
          turn.hidden = !hit;
          if (hit) shown += 1;
          if (query && hit) highlight(el, text, query);
          else if (el.firstElementChild) el.textContent = text;
        }
        empty.hidden = shown > 0;
        count.textContent = query ? `${shown} of ${texts.length} lines` : "";
      }, 120);
    });
  }
})();
