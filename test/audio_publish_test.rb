# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"
require "fileutils"
require_relative "buzzsprout_test" # FakeHttp
require_relative "../lib/pingback/publisher"
require_relative "../lib/pingback/episode_file"

# Phase 6: bin/episode audio N --descript LINK
#   Descript renders the audio -> new private Buzzsprout episode -> upload.
class AudioPublishTest < Minitest::Test
  FakeDescript = Struct.new(:link_seen, :url) do
    def publish_audio(link) = (self.link_seen = link; url)
  end

  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, "_posts"))
    FileUtils.mkdir_p(File.join(@root, "_data"))
    File.write(File.join(@root, "_config.yml"), "url: https://pingbackpodcast.com\n")
    File.write(File.join(@root, "_data/topics.yml"), "- { slug: rails, name: Rails & Ruby }\n")
    @post = File.join(@root, "_posts/2026-10-23-episode-4.md")
    File.write(@post, "---\ntitle: \"Four\"\nepisode: 4\ntopics: [rails]\nyoutube_id: abc\n---\nNotes.\n")
  end

  def teardown = FileUtils.remove_entry(@root)

  def run_audio(http, descript)
    bz = Pingback::Buzzsprout.new(podcast_id: "2443886", token: "t", http: http)
    downloader = ->(url, path) { @downloaded = url; File.binwrite(path, "MP3") }
    Pingback::Publisher.new(root: @root, buzzsprout: bz, out: (@out = StringIO.new))
                       .publish_audio(4, descript_link: "https://web.descript.com/p", descript: descript, downloader: downloader)
  end

  def test_creates_private_episode_uploads_audio_and_records_ids
    http = FakeHttp.new([201, { "id" => 20000001 }],
                        [201, { "upload" => { "id" => "u1", "upload_url" => "https://up/x" } }], [200, ""], [200, { "id" => 20000001 }])
    descript = FakeDescript.new(nil, "https://cdn.descript.com/files/episode.mp3?sig=1")
    run_audio(http, descript)

    create = JSON.parse(http.requests.first[:body])
    assert_equal({ "title" => "Four", "episode_number" => 4, "private" => true, "tags" => "Rails & Ruby" },
                 create.slice("title", "episode_number", "private", "tags"))
    assert_includes create["description"], "Notes."
    assert_equal "https://cdn.descript.com/files/episode.mp3?sig=1", @downloaded
    assert_equal "audio/mpeg", JSON.parse(http.requests[1][:body])["type"]
    fm = Pingback::EpisodeFile.new(@post)
    assert_equal 20000001, fm["buzzsprout_id"]
    assert_equal "https://web.descript.com/p", fm["descript_project"]
    assert_match(/private/, @out.string)
  end

  def test_no_token_is_requested_when_the_episode_is_not_ready
    File.write(@post, File.read(@post).sub("episode: 4\n", "episode: 4\nbuzzsprout_id: 5\n"))
    asked = []
    bz = -> { asked << :buzzsprout; Pingback::Buzzsprout.new(podcast_id: "1", token: "t", http: FakeHttp.new) }
    descript = -> { asked << :descript; FakeDescript.new }
    publisher = Pingback::Publisher.new(root: @root, buzzsprout: bz, out: StringIO.new)
    assert_raises(Pingback::Publisher::Error) do
      publisher.publish_audio(4, descript_link: "x", descript: descript, downloader: ->(*) {})
    end
    assert_empty asked
  end

  def test_refuses_when_the_episode_is_already_on_buzzsprout
    File.write(@post, File.read(@post).sub("episode: 4\n", "episode: 4\nbuzzsprout_id: 5\n"))
    error = assert_raises(Pingback::Publisher::Error) { run_audio(FakeHttp.new, FakeDescript.new) }
    assert_match(/already on Buzzsprout/, error.message)
  end
end

class EpisodeFileSetTest < Minitest::Test
  def test_date_string_ignores_a_trailing_comment
    Dir.mktmpdir do |dir|
      path = File.join(dir, "2026-10-30-episode-4.md")
      File.write(path, "---\ndate: 2026-10-30 23:00:00 -0700  # TODO: confirm\nepisode: 4\n---\n")
      assert_equal "2026-10-30 23:00:00 -0700", Pingback::EpisodeFile.new(path).date_string
    end
  end

  def test_set_adds_or_replaces_a_key_without_touching_the_rest
    Dir.mktmpdir do |dir|
      path = File.join(dir, "2026-10-23-episode-4.md")
      File.write(path, "---\ntitle: \"Four\"\nepisode: 4\nchapters:\n  - { t: \"0:00\", title: \"Hi\" }\n---\nBody\n")
      Pingback::EpisodeFile.new(path).set!("buzzsprout_id", 123)
      Pingback::EpisodeFile.new(path).set!("buzzsprout_id", 456)
      assert_equal "---\ntitle: \"Four\"\nepisode: 4\nbuzzsprout_id: 456\nchapters:\n  - { t: \"0:00\", title: \"Hi\" }\n---\nBody\n", File.read(path)
    end
  end
end
