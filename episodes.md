---
layout: base
title: Episodes
permalink: /episodes/
description: "Every episode of the Pingback Podcast, with show notes, chapters, best moments, and full transcripts."
---
<h1 class="page-title">Episodes</h1>
<nav class="topic-filter" aria-label="Filter by topic">
  <a class="chip chip--ruby" href="{{ '/episodes/' | relative_url }}" data-topic="all" aria-current="true">All</a>
  {%- for topic in site.data.topics %}
  <a class="chip" href="{{ '/topics/' | append: topic.slug | append: '/' | relative_url }}" data-topic="{{ topic.slug }}">{{ topic.name }}</a>
  {%- endfor %}
</nav>
{% include episode-list.html posts=site.posts %}
<p class="topic-empty card" hidden>No episodes on this topic yet.</p>
<script src="{{ '/assets/js/topics.js' | relative_url }}" defer></script>
