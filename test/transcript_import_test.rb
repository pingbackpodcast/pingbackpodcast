# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"
require "fileutils"
require_relative "../lib/pingback/transcript_import"

# Phase 2: `bin/episode transcript N` saves Buzzsprout's transcript as site data.
class TranscriptImportTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, "_posts"))
    File.write(File.join(@root, "_config.yml"), <<~YAML)
      buzzsprout_podcast_id: "2443886"
      speakers:
        "Greg": "Greg Molnar"
    YAML
    File.write(File.join(@root, "_posts/2026-10-09-episode-2.md"), <<~MD)
      ---
      title: "Two"
      episode: 2
      buzzsprout_id: 19937319
      speaker_names:
        "Raul": "Raul Papadineti"
      ---
      Notes.
    MD
    @requested = []
    @fetch = lambda do |url|
      @requested << url
      { "segments" => [
        { "speaker" => "Greg", "startTime" => 1.0, "endTime" => 1.2, "body" => "Welcome." },
        { "speaker" => "Raul", "startTime" => 2.0, "endTime" => 2.2, "body" => "Thanks!" }
      ] }
    end
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def run_import
    Pingback::TranscriptImport.new(root: @root, fetch: @fetch).run(2)
  end

  def test_fetches_the_public_buzzsprout_transcript
    run_import
    assert_equal ["https://www.buzzsprout.com/2443886/19937319/transcript.json"], @requested
  end

  def test_writes_turns_with_site_and_episode_speaker_names
    path = run_import
    assert_equal File.join(@root, "_data/transcripts/episode-2.json"), path
    data = JSON.parse(File.read(path))
    assert_equal "buzzsprout", data["source"]
    assert_equal [{ "speaker" => "Greg Molnar", "t" => 1.0, "text" => "Welcome." },
                  { "speaker" => "Raul Papadineti", "t" => 2.0, "text" => "Thanks!" }], data["turns"]
  end

  def test_unknown_episode_is_an_error
    error = assert_raises(Pingback::TranscriptImport::Error) do
      Pingback::TranscriptImport.new(root: @root, fetch: @fetch).run(9)
    end
    assert_match(/episode 9/, error.message)
  end

  def test_episode_without_buzzsprout_id_is_an_error
    File.write(File.join(@root, "_posts/2026-10-02-episode-1.md"), "---\ntitle: One\nepisode: 1\n---\n")
    error = assert_raises(Pingback::TranscriptImport::Error) do
      Pingback::TranscriptImport.new(root: @root, fetch: @fetch).run(1)
    end
    assert_match(/buzzsprout_id/, error.message)
  end
end
