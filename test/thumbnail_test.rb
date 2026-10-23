# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/pingback/thumbnail"

# Phase 2: `bin/episode thumbnail N` saves the YouTube thumbnail locally.
class ThumbnailTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, "_posts"))
    File.write(File.join(@root, "_posts/2026-10-16-episode-3.md"), "---\nepisode: 3\nyoutube_id: yW4oRzt9AqE\n---\n")
    @urls = []
  end

  def teardown = FileUtils.remove_entry(@root)

  def test_downloads_maxres_and_saves_under_assets
    fetch = ->(url) { @urls << url; "JPEGBYTES" }
    path = Pingback::Thumbnail.new(root: @root, fetch: fetch, resize: ->(_src, dst) { FileUtils.cp(_src, dst) }).run(3)
    assert_equal ["https://i.ytimg.com/vi/yW4oRzt9AqE/maxresdefault.jpg"], @urls
    assert_equal File.join(@root, "assets/images/episodes/episode-3.jpg"), path
    assert_equal "JPEGBYTES", File.read(path)
  end

  def test_falls_back_to_hq_when_no_maxres
    fetch = ->(url) { @urls << url; url.include?("maxres") ? nil : "HQ" }
    Pingback::Thumbnail.new(root: @root, fetch: fetch, resize: ->(s, d) { FileUtils.cp(s, d) }).run(3)
    assert_equal 2, @urls.size
    assert_match(/hqdefault/, @urls.last)
  end

  def test_episode_without_youtube_id_is_an_error
    File.write(File.join(@root, "_posts/2026-10-02-episode-1.md"), "---\nepisode: 1\n---\n")
    assert_raises(Pingback::Thumbnail::Error) { Pingback::Thumbnail.new(root: @root, fetch: ->(_) {}).run(1) }
  end
end
