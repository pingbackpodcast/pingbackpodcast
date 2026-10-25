# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "yaml"
require "tmpdir"
require "fileutils"
require_relative "buzzsprout_test" # FakeHttp
require_relative "../lib/pingback/publisher"

# Phase 6: bin/episode sync / publish / status against a fake Buzzsprout.
class PublisherTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, "_posts"))
    FileUtils.mkdir_p(File.join(@root, "_data"))
    File.write(File.join(@root, "_config.yml"), "url: https://pingbackpodcast.com\nbuzzsprout_podcast_id: \"2443886\"\n")
    File.write(File.join(@root, "_data/topics.yml"), "- { slug: rails, name: Rails & Ruby }\n- { slug: ai, name: AI & agents }\n")
    File.write(File.join(@root, "_data/platforms.yml"), "- { name: Spotify, url: \"https://open.spotify.com/show/x\" }\n")
    File.write(File.join(@root, "_posts/2026-10-16-episode-3.md"), <<~MD)
      ---
      title: "Sam Ruby on Roundhouse"
      date: 2026-10-16 23:00:00 -0700
      episode: 3
      topics: [rails, ai]
      youtube_id: yW4oRzt9AqE
      buzzsprout_id: 19975498
      chapters:
        - { t: "0:00", title: "Welcome" }
        - { t: "1:59", title: "Background" }
        - { t: "2:43", title: "Ballroom" }
      ---
      Joel and Greg interview **Sam Ruby**.

      - [Sam on X](https://x.com/samruby)
    MD
    @clipboard = []
  end

  def teardown = FileUtils.remove_entry(@root)

  def publisher(http, out: StringIO.new)
    @out = out
    bz = Pingback::Buzzsprout.new(podcast_id: "2443886", token: "tok", http: http)
    Pingback::Publisher.new(root: @root, buzzsprout: bz, clipboard: ->(text) { @clipboard << text }, out: out)
  end

  def remote(overrides = {})
    { "id" => 19975498, "title" => "Pingback Podcast - Episode 3", "description" => "", "tags" => "",
      "episode_number" => nil, "private" => true, "published_at" => "2026-10-17T02:00:00-04:00", "duration" => 3254 }.merge(overrides)
  end

  def test_sync_pushes_metadata_and_chapters_then_copies_youtube_text
    http = FakeHttp.new([200, remote], [200, remote], [200, []])
    publisher(http).sync(3)
    get, patch, chapters = http.requests
    assert_equal :get, get[:method]
    body = JSON.parse(patch[:body])
    assert_equal :patch, patch[:method]
    assert_equal "Sam Ruby on Roundhouse", body["title"]
    assert_equal 3, body["episode_number"]
    assert_equal "Rails & Ruby,AI & agents", body["tags"]
    assert_includes body["description"], "<strong>Sam Ruby</strong>"
    assert_includes body["description"], 'href="https://pingbackpodcast.com/episodes/episode-3/"'
    refute body.key?("private"), "sync never publishes"
    assert_equal 3, JSON.parse(chapters[:body])["chapters"].size
    assert_match(/^0:00 Welcome$/, @clipboard.first)
    assert_match(%r{studio.youtube.com/video/yW4oRzt9AqE/edit}, @out.string)
  end

  def test_dry_run_only_reads_and_reports_changes
    http = FakeHttp.new([200, remote], [200, []])
    publisher(http).sync(3, dry_run: true)
    assert_equal %i[get get], http.requests.map { |r| r[:method] }
    assert_match(/title: "Pingback Podcast - Episode 3" -> "Sam Ruby on Roundhouse"/, @out.string)
    assert_match(/chapters: 0 -> 3/, @out.string)
    assert_empty @clipboard
  end

  def test_sync_reports_nothing_to_do_when_already_in_sync
    desc = nil
    http = FakeHttp.new([200, remote], [200, []])
    p = publisher(http)
    desc = p.send(:description_html, Pingback::EpisodeFile.find(@root, 3))
    synced = remote("title" => "Sam Ruby on Roundhouse", "description" => desc, "tags" => "Rails & Ruby,AI & agents", "episode_number" => 3)
    chapters = [{ "title" => "Welcome", "start_time" => "00:00:00" }, { "title" => "Background", "start_time" => "00:01:59" },
                { "title" => "Ballroom", "start_time" => "00:02:43" }]
    http2 = FakeHttp.new([200, synced], [200, chapters])
    publisher(http2).sync(3, dry_run: true)
    assert_match(/already in sync/, @out.string)
  end

  def test_publish_makes_public_at_the_post_date
    http = FakeHttp.new([200, remote("private" => false)])
    publisher(http).publish(3)
    body = JSON.parse(http.requests.first[:body])
    assert_equal({ "private" => false, "published_at" => "2026-10-16T23:00:00-07:00" }, body)
  end

  def test_publish_can_schedule
    http = FakeHttp.new([200, remote])
    publisher(http).publish(3, at: "2026-10-30 23:00 -0700")
    assert_equal "2026-10-30T23:00:00-07:00", JSON.parse(http.requests.first[:body])["published_at"]
  end

  def test_status_summarises_buzzsprout
    http = FakeHttp.new([200, remote], [200, []])
    publisher(http).status(3)
    assert_match(/Buzzsprout: private/, @out.string)
    assert_match(/54:14/, @out.string)
    assert_match(/chapters: 0 on Buzzsprout, 3 in the repo/, @out.string)
  end

  def test_youtube_text_needs_no_buzzsprout
    File.write(File.join(@root, "_posts/2026-10-23-episode-4.md"),
               "---\ntitle: Four\nepisode: 4\nyoutube_id: abc\n---\nNotes.\n")
    Pingback::Publisher.new(root: @root, buzzsprout: nil, clipboard: ->(t) { @clipboard << t }, out: StringIO.new).youtube_text(4)
    assert_match(%r{Notes\.\n\nShow notes, best moments}, @clipboard.first)
  end

  # The token (a 1Password prompt) is only requested once the episode checks
  # pass, so a typo'd episode number never pops up an authorization dialog.
  def test_token_is_not_requested_for_a_missing_episode
    asked = false
    factory = -> { asked = true; Pingback::Buzzsprout.new(podcast_id: "1", token: "t", http: FakeHttp.new) }
    p = Pingback::Publisher.new(root: @root, buzzsprout: factory, out: StringIO.new)
    assert_raises(Pingback::Publisher::Error) { p.sync(9) }
    refute asked, "no token request before the episode is found"
  end

  # Episodes 1-3 went out before the pipeline existed; Buzzsprout keeps them as is.
  def lock_through(n)
    File.write(File.join(@root, "_config.yml"), "buzzsprout_locked_through: #{n}\n", mode: "a")
  end

  def test_locked_episodes_refuse_sync_publish_and_audio_without_asking_for_a_token
    lock_through(3)
    asked = false
    factory = -> { asked = true; Pingback::Buzzsprout.new(podcast_id: "1", token: "t", http: FakeHttp.new) }
    p = Pingback::Publisher.new(root: @root, buzzsprout: factory, out: StringIO.new)
    [-> { p.sync(3) }, -> { p.publish(3) },
     -> { p.publish_audio(3, descript_link: "x", descript: -> { flunk }, downloader: ->(*) { flunk }) }].each do |call|
      error = assert_raises(Pingback::Publisher::Error) { call.call }
      assert_match(/episode 3 is locked/, error.message)
    end
    refute asked, "no token request for a locked episode"
  end

  def test_locked_episodes_still_allow_dry_run_and_status
    lock_through(3)
    publisher(FakeHttp.new([200, remote], [200, []])).sync(3, dry_run: true)
    publisher(FakeHttp.new([200, remote], [200, []])).status(3)
  end

  def test_episodes_after_the_lock_sync_normally
    lock_through(2)
    publisher(FakeHttp.new([200, remote], [200, remote], [200, []])).sync(3)
    assert_equal 1, @clipboard.size
  end

  # Hosts publish the audio privately to Buzzsprout from Descript; the
  # pipeline finds that episode by its number in the title.
  def four(extra = "")
    File.write(File.join(@root, "_posts/2026-10-24-episode-4.md"), "---\ntitle: Four\nepisode: 4\n#{extra}---\nNotes.\n")
  end

  def listing
    [{ "id" => 20014767, "title" => "Pingback Podcast Episode 4: Josef Strzibny", "private" => true },
     { "id" => 19975498, "title" => "Pingback Podcast - Episode 3 - Sam Ruby", "private" => false },
     { "id" => 19902168, "title" => "Pingback Podcast - Episode 1", "private" => false }]
  end

  def test_link_finds_the_buzzsprout_episode_by_number_and_records_it
    four
    out = StringIO.new
    publisher(FakeHttp.new([200, listing]), out: out).link_buzzsprout(4)
    assert_match(/^buzzsprout_id: 20014767$/, File.read(File.join(@root, "_posts/2026-10-24-episode-4.md")))
    assert_match(/Episode 4: Josef Strzibny.*20014767.*private/, out.string)
  end

  def test_link_does_not_mistake_episode_14_for_4
    four
    list = [{ "id" => 1, "title" => "Pingback Podcast Episode 14", "private" => true }]
    error = assert_raises(Pingback::Publisher::Error) { publisher(FakeHttp.new([200, list])).link_buzzsprout(4) }
    assert_match(/no Buzzsprout episode with "Episode 4"/, error.message)
  end

  def test_link_refuses_two_matches
    four
    list = listing + [{ "id" => 2, "title" => "Episode 4 (re-upload)", "private" => true }]
    error = assert_raises(Pingback::Publisher::Error) { publisher(FakeHttp.new([200, list])).link_buzzsprout(4) }
    assert_match(/2 Buzzsprout episodes/, error.message)
  end

  def test_link_leaves_an_existing_id_alone_without_asking_for_a_token
    four("buzzsprout_id: 555\n")
    p = Pingback::Publisher.new(root: @root, buzzsprout: -> { flunk "no token needed" }, out: StringIO.new)
    p.link_buzzsprout(4)
    assert_match(/^buzzsprout_id: 555$/, File.read(File.join(@root, "_posts/2026-10-24-episode-4.md")))
  end

  def test_site_config_locks_episodes_one_to_three
    assert_equal 3, YAML.safe_load_file(File.expand_path("../_config.yml", __dir__))["buzzsprout_locked_through"]
  end

  def test_episode_without_buzzsprout_id_explains_what_to_do
    File.write(File.join(@root, "_posts/2026-10-23-episode-4.md"), "---\ntitle: Four\nepisode: 4\n---\n")
    error = assert_raises(Pingback::Publisher::Error) { publisher(FakeHttp.new).sync(4) }
    assert_match(/buzzsprout_id/, error.message)
  end
end
