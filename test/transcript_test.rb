# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/pingback/transcript"

# Phase 2: Buzzsprout word segments -> speaker turns for the episode page.
class TranscriptTest < Minitest::Test
  def word(speaker, start, body)
    { "speaker" => speaker, "startTime" => start, "endTime" => start + 0.3, "body" => body }
  end

  def test_groups_consecutive_words_by_speaker
    segs = [word("Greg", 1.0, "Hi,"), word("Greg", 1.4, "Joel."),
            word("Joel Gaff, Jr.", 2.0, "Hey"), word("Joel Gaff, Jr.", 2.3, "Greg.")]
    turns = Pingback::Transcript.turns(segs)
    assert_equal [["Greg", 1.0, "Hi, Joel."], ["Joel Gaff, Jr.", 2.0, "Hey Greg."]],
                 turns.map { |t| [t[:speaker], t[:t], t[:text]] }
  end

  def test_long_monologue_splits_into_paragraphs_at_sentence_ends
    segs = [word("Sam", 0.0, "First."), word("Sam", 30.0, "Still"), word("Sam", 50.0, "going."),
            word("Sam", 51.0, "New"), word("Sam", 52.0, "paragraph.")]
    turns = Pingback::Transcript.turns(segs, paragraph_seconds: 45)
    assert_equal ["First. Still going.", "New paragraph."], turns.map { |t| t[:text] }
    assert_equal [0.0, 51.0], turns.map { |t| t[:t] }
    assert_equal %w[Sam Sam], turns.map { |t| t[:speaker] }
  end

  def test_does_not_split_mid_sentence
    segs = [word("Sam", 0.0, "This"), word("Sam", 60.0, "keeps"), word("Sam", 61.0, "going.")]
    assert_equal ["This keeps going."], Pingback::Transcript.turns(segs, paragraph_seconds: 45).map { |t| t[:text] }
  end

  def test_renames_speakers
    segs = [word("Greg", 1.0, "Hi."), word("Joel Gaff, Jr.", 2.0, "Hey.")]
    names = { "Greg" => "Greg Molnar", "Joel Gaff, Jr." => "Joel Gaff Jr." }
    assert_equal ["Greg Molnar", "Joel Gaff Jr."],
                 Pingback::Transcript.turns(segs, names: names).map { |t| t[:speaker] }
  end

  def test_skips_blank_words_and_rounds_start_times
    segs = [word("Greg", 1.234, "Hi"), word("Greg", 1.5, "  "), word("Greg", 1.7, "there.")]
    turn = Pingback::Transcript.turns(segs).first
    assert_equal "Hi there.", turn[:text]
    assert_equal 1.2, turn[:t]
  end

  def test_chapters_from_buzzsprout_json
    json = { "chapters" => [{ "startTime" => 0.0, "title" => "Welcome" },
                            { "startTime" => 119.0, "title" => "Background" },
                            { "startTime" => 3725.0, "title" => "Wrap" }] }
    assert_equal [{ "t" => "0:00", "title" => "Welcome" }, { "t" => "1:59", "title" => "Background" },
                  { "t" => "1:02:05", "title" => "Wrap" }],
                 Pingback::Transcript.chapters(json)
  end

  def test_clock_formats_seconds
    assert_equal "0:07", Pingback::Transcript.clock(7.9)
    assert_equal "12:34", Pingback::Transcript.clock(754)
    assert_equal "1:00:00", Pingback::Transcript.clock(3600)
  end
end
