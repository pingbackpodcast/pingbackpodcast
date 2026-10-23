# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/pingback/youtube_text"

# Phase 6: the YouTube description, pasted into YouTube Studio by hand.
class YoutubeTextTest < Minitest::Test
  BODY = <<~MD
    Joel and Greg interview Sam Ruby.

    He talks about *Roundhouse* and [Spinel](https://github.com/matz/spinel).

    ## Find Sam

    - [Sam's blog](https://intertwingly.net)
    - [Sam on X](https://x.com/samruby)
  MD

  def build(chapters: [{ "t" => "0:00", "title" => "Welcome" }, { "t" => "1:59", "title" => "Background" },
                       { "t" => "2:43", "title" => "Ballroom" }])
    Pingback::YoutubeText.build(
      body: BODY, chapters: chapters, url: "https://pingbackpodcast.com/episodes/episode-3/",
      platforms: [{ "name" => "Spotify", "url" => "https://open.spotify.com/show/x" },
                  { "name" => "Overcast", "url" => "" }]
    )
  end

  def test_notes_become_plain_text_with_links_spelled_out
    text = build
    assert_includes text, "Joel and Greg interview Sam Ruby."
    assert_includes text, "He talks about Roundhouse and Spinel (https://github.com/matz/spinel)."
    assert_includes text, "Find Sam\n- Sam's blog: https://intertwingly.net\n- Sam on X: https://x.com/samruby"
    refute_match(/[*#\[\]]/, text.lines.reject { |l| l.include?("http") }.join, "no markdown left")
  end

  def test_chapters_listed_for_youtube
    assert_includes build, "Chapters\n0:00 Welcome\n1:59 Background\n2:43 Ballroom"
  end

  def test_links_to_the_episode_page_and_live_platforms_only
    text = build
    assert_includes text, "Show notes, best moments and the full transcript: https://pingbackpodcast.com/episodes/episode-3/"
    assert_includes text, "Spotify: https://open.spotify.com/show/x"
    refute_includes text, "Overcast"
  end

  def test_chapters_must_start_at_zero_and_number_at_least_three
    assert_raises(Pingback::YoutubeText::Error) { build(chapters: [{ "t" => "0:05", "title" => "a" }, { "t" => "1:00", "title" => "b" }, { "t" => "2:00", "title" => "c" }]) }
    assert_raises(Pingback::YoutubeText::Error) { build(chapters: [{ "t" => "0:00", "title" => "a" }, { "t" => "1:00", "title" => "b" }]) }
  end

  def test_chapters_must_be_ten_seconds_apart
    error = assert_raises(Pingback::YoutubeText::Error) do
      build(chapters: [{ "t" => "0:00", "title" => "a" }, { "t" => "0:05", "title" => "b" }, { "t" => "1:00", "title" => "c" }])
    end
    assert_match(/10 seconds/, error.message)
  end

  def test_no_chapters_is_fine
    refute_includes build(chapters: []), "Chapters"
  end
end
