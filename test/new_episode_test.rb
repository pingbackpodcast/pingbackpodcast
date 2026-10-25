# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"
require "fileutils"
require "yaml"
require "date"
require_relative "../lib/pingback/new_episode"

# Phase 7: bin/episode new N --youtube URL scaffolds the episode file.
class NewEpisodeTest < Minitest::Test
  INFO = { "id" => "abcDEF12345", "title" => "Episode 4 - Jane Doe", "duration" => 3125.0,
           "upload_date" => "20261030",
           "chapters" => [{ "start_time" => 0.0, "title" => "Welcome" }, { "start_time" => 95.0, "title" => "Jane's story" }] }.freeze

  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, "_posts"))
    @runner = ->(*cmd) { @cmd = cmd; [JSON.generate(INFO), true] }
  end

  def teardown = FileUtils.remove_entry(@root)

  def scaffold = Pingback::NewEpisode.new(root: @root, runner: @runner).run(4, youtube: "https://youtu.be/abcDEF12345")

  def front(path) = YAML.safe_load(File.read(path)[/\A---\n(.*?)\n---/m, 1], permitted_classes: [Date, Time])

  def test_a_private_video_explains_it_must_be_unlisted
    @runner = ->(*) { ["", false] }
    error = assert_raises(Pingback::NewEpisode::Error) { scaffold }
    assert_match(/Unlisted, not Private/, error.message)
  end

  def test_writes_a_post_from_the_youtube_details
    path = scaffold
    assert_equal File.join(@root, "_posts/2026-10-30-episode-4.md"), path
    fm = front(path)
    assert_equal 4, fm["episode"]
    assert_equal "abcDEF12345", fm["youtube_id"]
    assert_equal "52 min", fm["duration"]
    assert_equal [{ "t" => "0:00", "title" => "Welcome" }, { "t" => "1:35", "title" => "Jane's story" }], fm["chapters"]
    assert_match(/TODO/, fm["title"])
    assert_match(/TODO/, fm["description"])
    assert_equal [], fm["topics"]
    assert_match(/TODO: show notes/, File.read(path))
    assert_includes @cmd, "--dump-single-json"
  end

  def test_refuses_to_overwrite_an_existing_episode
    File.write(File.join(@root, "_posts/2026-10-23-episode-4.md"), "---\nepisode: 4\n---\n")
    assert_raises(Pingback::NewEpisode::Error) { scaffold }
  end

  def test_yt_dlp_failure_is_explained
    @runner = ->(*) { ["", false] }
    error = assert_raises(Pingback::NewEpisode::Error) { scaffold }
    assert_match(/yt-dlp/, error.message)
  end
end
