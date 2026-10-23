# frozen_string_literal: true

require "test_helper"
require "json"

# Phase 2: the episode page — video, chapters and transcript that seek it.
class EpisodePageTest < SiteTest
  EP3 = "/episodes/episode-3/"

  def transcript(n)
    JSON.parse(File.read(File.join(SiteBuild::ROOT, "_data/transcripts/episode-#{n}.json")))["turns"]
  end

  def test_video_is_a_click_to_load_facade_with_local_thumbnail
    video = page(EP3).at_css(".episode-video[data-youtube-id='yW4oRzt9AqE']")
    assert video, "video container carries the YouTube id"
    button = video.at_css("button.video-facade")
    assert button, "a play button stands in until clicked"
    assert_match(/Play/i, button["aria-label"].to_s)
    assert_equal "/assets/images/episodes/episode-3.jpg", button.at_css("img")&.[]("src")
    refute video.at_css("iframe"), "no iframe until the visitor asks for the video"
  end

  def test_thumbnails_exist_for_every_episode
    (1..3).each do |n|
      assert File.file?(File.join(SiteBuild::ROOT, "assets/images/episodes/episode-#{n}.jpg")), "thumbnail #{n}"
    end
  end

  def test_chapters_sit_beside_the_notes_and_seek
    doc = page(EP3)
    links = doc.css(".episode-body aside.episode-aside .chapters a[data-seek]")
    assert_equal 24, links.size
    assert_equal %w[0 119 163], links.first(3).map { |a| a["data-seek"] }
    assert_equal "https://www.youtube.com/watch?v=yW4oRzt9AqE&t=119s", links[1]["href"], "works without JS"
    assert doc.at_css(".episode-body .episode-notes.prose"), "notes column"
  end

  def test_episode_without_chapters_has_no_chapters_box
    refute page("/episodes/episode-1/").at_css(".chapters")
  end

  def test_full_transcript_with_speakers_timestamps_and_search
    doc = page(EP3)
    section = doc.at_css("section#transcript")
    assert section, "transcript section"
    search = section.at_css("input[type=search]")
    assert search, "search box"
    assert section.at_css("label[for='#{search['id']}']"), "search box has a label"
    turns = section.css(".turn")
    assert_equal transcript(3).size, turns.size
    first = turns.first
    assert_equal "Joel Gaff Jr.", first.at_css(".turn__speaker").text.strip
    stamp = first.at_css("a.timestamp[data-seek]")
    assert_equal "20", stamp["data-seek"]
    assert_equal "0:20", stamp.text.strip
    assert_match(/Welcome back to the Pingback Podcast/, first.at_css(".turn__text").text)
  end

  def test_every_episode_has_a_transcript
    (1..3).each { |n| assert page("/episodes/episode-#{n}/").at_css("section#transcript .turn"), "episode #{n}" }
  end

  def test_audio_player_is_offered_as_listen_instead
    assert page(EP3).at_css(".episode-listen #buzzsprout-player-19975498")
  end

  def test_episode_script_is_loaded_deferred
    script = page(EP3).at_css("script[src='/assets/js/episode.js']")
    assert script, "episode.js"
    assert script.key?("defer")
  end

  def test_previous_and_next_episode_cards
    nav = page("/episodes/episode-2/").at_css("nav.episode-pager")
    assert nav, "pager"
    hrefs = nav.css("a.card__link").map { |a| a["href"] }
    assert_equal ["/episodes/episode-1/", "/episodes/episode-3/"], hrefs
  end
end
