// Episodes page: topic chips filter the cards in place (links still go to
// the topic pages without JavaScript or with a modifier key).
(() => {
  "use strict";
  const chips = [...document.querySelectorAll(".topic-filter [data-topic]")];
  const cards = [...document.querySelectorAll(".episode-card[data-topics]")];
  const empty = document.querySelector(".topic-empty");
  if (!chips.length) return;

  function show(topic) {
    let shown = 0;
    for (const card of cards) {
      const hit = topic === "all" || card.dataset.topics.split(" ").includes(topic);
      card.hidden = !hit;
      if (hit) shown += 1;
    }
    for (const chip of chips) {
      const active = chip.dataset.topic === topic;
      chip.classList.toggle("chip--ruby", active);
      if (active) chip.setAttribute("aria-current", "true"); else chip.removeAttribute("aria-current");
    }
    if (empty) empty.hidden = shown > 0;
  }

  for (const chip of chips) {
    chip.addEventListener("click", (event) => {
      if (event.metaKey || event.ctrlKey || event.shiftKey) return;
      event.preventDefault();
      show(chip.dataset.topic);
      const url = chip.dataset.topic === "all" ? location.pathname : `${location.pathname}#${chip.dataset.topic}`;
      history.replaceState(null, "", url);
    });
  }

  const initial = location.hash.slice(1);
  if (chips.some((c) => c.dataset.topic === initial)) show(initial);
})();
