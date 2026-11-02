# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "fileutils"
require_relative "../lib/pingback/release_check"

# bin/episode check N: the host's release checklist (YouTube unlisted with
# description, chapters and thumbnail; audio and chapters on Buzzsprout;
# website import; everything scheduled for the release slot), checked
# against YouTube, Buzzsprout and the repo. Read-only.
class ReleaseCheckTest < Minitest::Test
  RELEASE = "2026-11-02 02:00:00 -0800" # Monday 9:00 in the Azores (UTC-1)
  CHAPTERS = [{ "start_time" => 0, "title" => "Welcome" }, { "start_time" => 119, "title" => "Rails" },
              { "start_time" => 163, "title" => "AI" }].freeze

  class FakeBuzzsprout
    attr_accessor :ep, :chapter_list

    def initialize(ep, chapter_list) = (@ep, @chapter_list = ep, chapter_list)
    def episode(_id) = @ep
    def chapters(_id) = @chapter_list
  end

  def setup
    @root = Dir.mktmpdir
    %w[_posts _data/transcripts assets/images/episodes assets/images/og].each { |d| FileUtils.mkdir_p(File.join(@root, d)) }
    File.write(File.join(@root, "_config.yml"), <<~YML)
      url: https://pingbackpodcast.com
      release: { weekday: Monday, time: "09:00", zone: Atlantic/Azores }
    YML
    write_post
    %w[_data/transcripts/episode-5.json assets/images/episodes/episode-5.jpg assets/images/og/episode-5.png].each do |f|
      File.write(File.join(@root, f), "x")
    end
    @video = { "id" => "vid5", "availability" => "unlisted", "duration" => 3000, "chapters" => CHAPTERS,
               "description" => "Notes.\n\nhttps://pingbackpodcast.com/episodes/episode-5/\n\n0:00 Welcome" }
    @bz = FakeBuzzsprout.new(
      { "id" => 555, "audio_url" => "https://www.buzzsprout.com/x/555.mp3", "duration" => 3010,
        "private" => false, "published_at" => "2026-11-02T10:00:00.000+00:00" },
      [{ "title" => "Welcome", "start_time" => "00:00:00" }, { "title" => "Rails", "start_time" => "00:01:59" },
       { "title" => "AI", "start_time" => "00:02:43" }]
    )
    @git = ->(*_args) { ["", true] }
    @now = Time.utc(2026, 11, 1, 18)
  end

  def teardown = FileUtils.remove_entry(@root)

  def write_post(date: RELEASE, extra: "")
    Dir[File.join(@root, "_posts/*")].each { |f| File.delete(f) }
    File.write(File.join(@root, "_posts/#{date[0, 10]}-episode-5.md"), <<~MD)
      ---
      title: "Joel and Greg on things"
      date: #{date}
      episode: 5
      youtube_id: vid5
      buzzsprout_id: 555
      chapters:
        - { t: "0:00", title: "Welcome" }
        - { t: "1:59", title: "Rails" }
        - { t: "2:43", title: "AI" }
      #{extra}
      ---
      Show notes.
    MD
  end

  def check(video: @video)
    out = StringIO.new
    ok = Pingback::ReleaseCheck.new(root: @root, buzzsprout: @bz, youtube: ->(_id) { video },
                                    git: @git, now: @now, out: out).run(5)
    [ok, out.string]
  end

  def line(out, label) = out.lines.find { |l| l.include?(label) } || flunk("no line for #{label}:\n#{out}")

  def test_ready_episode_lacks_only_the_youtube_schedule
    ok, out = check
    refute ok, out
    assert_match(/✓/, line(out, "Unlisted on YouTube"))
    assert_match(/✓/, line(out, "YouTube description"))
    assert_match(/✓/, line(out, "Website link in the YouTube description"))
    assert_match(/✓/, line(out, "Chapters in the YouTube description"))
    assert_match(/\?/, line(out, "Custom thumbnail"))
    assert_match(/✓/, line(out, "Audio on Buzzsprout"))
    assert_match(/✓/, line(out, "Chapters on Buzzsprout"))
    assert_match(/✓/, line(out, "Website post"))
    assert_match(/✓/, line(out, "Release time"))
    assert_match(/✓/, line(out, "Buzzsprout scheduled"))
    assert_match(/✗/, line(out, "YouTube scheduled")) # still Unlisted: schedule it in Studio
    assert_match(%r{studio.youtube.com/video/vid5/edit}, out)
  end

  def test_all_done_once_youtube_is_public
    ok, out = check(video: @video.merge("availability" => "public"))
    assert ok, out
  end

  def test_youtube_description_not_pasted_and_chapters_missing
    ok, out = check(video: @video.merge("description" => "", "chapters" => []))
    refute ok
    assert_match(/✗.*empty/, line(out, "YouTube description"))
    assert_match(/✗.*bin\/episode sync 5/, line(out, "Website link in the YouTube description"))
    assert_match(/✗/, line(out, "Chapters in the YouTube description"))
  end

  def test_chapters_breaking_youtube_rules
    _, out = check(video: @video.merge("chapters" => CHAPTERS.first(2)))
    assert_match(/✗.*at least 3/, line(out, "Chapters in the YouTube description"))
  end

  def test_private_video_is_unknown_once_scheduled
    _, out = check(video: nil)
    assert_match(/\?.*Private/, line(out, "Unlisted on YouTube"))
    assert_match(/\?/, line(out, "YouTube scheduled"))
  end

  def test_buzzsprout_audio_missing_or_wrong_length_and_chapters_not_pasted
    @bz.ep = @bz.ep.merge("audio_url" => nil, "duration" => 0)
    @bz.chapter_list = []
    ok, out = check
    refute ok
    assert_match(/✗/, line(out, "Audio on Buzzsprout"))
    assert_match(/✗.*0 of 3/, line(out, "Chapters on Buzzsprout"))

    @bz.ep = @bz.ep.merge("audio_url" => "https://x/555.mp3", "duration" => 1200)
    _, out = check
    assert_match(/✗.*20:00.*50:00/, line(out, "Audio on Buzzsprout"))
  end

  def test_buzzsprout_still_private_or_at_another_time
    @bz.ep = @bz.ep.merge("private" => true)
    _, out = check
    assert_match(/✗.*private/, line(out, "Buzzsprout scheduled"))

    @bz.ep = @bz.ep.merge("private" => false, "published_at" => "2026-11-02T09:00:00Z")
    _, out = check
    assert_match(/✗.*bin\/episode publish 5/, line(out, "Buzzsprout scheduled"))
  end

  def test_release_time_must_be_the_slot
    write_post(date: "2026-11-02 09:00:00 -0800")
    _, out = check
    assert_match(/✗.*Monday 09:00 Atlantic\/Azores/, line(out, "Release time"))
  end

  def test_website_post_with_todos_or_missing_files
    write_post(extra: 'description: "TODO: write"')
    File.delete(File.join(@root, "_data/transcripts/episode-5.json"))
    _, out = check
    assert_match(/✗.*TODO.*transcript/, line(out, "Website post"))
  end

  def test_website_post_not_pushed
    @git = ->(*args) { args.include?("origin/main") ? ["", false] : ["", true] }
    _, out = check
    assert_match(/✗.*git push/, line(out, "Website post pushed"))
  end

  def test_buzzsprout_unreachable_marks_its_items_unknown
    @bz = Object.new.tap { |o| def o.episode(_) = raise(Pingback::Buzzsprout::Error, "no token") }
    _, out = check
    assert_match(/\?.*no token/, line(out, "Audio on Buzzsprout"))
  end
end
