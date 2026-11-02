# frozen_string_literal: true

require "time"
require "yaml"
require_relative "episode_file"
require_relative "buzzsprout"
require_relative "transcript"

module Pingback
  # bin/episode check N: the host's release checklist, checked against
  # YouTube (yt-dlp), Buzzsprout and the repo. Read-only. Each item is ✓ done,
  # ✗ not done (with what to do) or ? can't tell from here (check by hand).
  #
  #   YouTube:    Unlisted, Descript's description with chapters, chapters
  #               YouTube accepts, custom thumbnail
  #   Buzzsprout: the audio-only export arrived, chapters pasted
  #   Website:    post imported (no TODOs, transcript, thumbnail, share
  #               card), committed and pushed
  #   Release:    post, Buzzsprout and YouTube all set to the release slot
  #               (`release:` in _config.yml, e.g. Monday 09:00 Atlantic/Azores)
  class ReleaseCheck
    MARKS = { ok: "✓", todo: "✗", unknown: "?" }.freeze
    LENGTH_SLACK = 60 # seconds between the YouTube and Buzzsprout lengths

    # buzzsprout: a client, or a proc that builds one. youtube: id -> yt-dlp
    # info hash, or nil when the video can't be read (Private). git: runs git
    # with the given args in root, returns [stdout, success].
    def initialize(root:, buzzsprout:, youtube:, git:, now: Time.now, out: $stdout)
      @root, @buzzsprout, @youtube, @git, @now, @out = root, buzzsprout, youtube, git, now, out
      @config = YAML.safe_load_file(File.join(root, "_config.yml")) || {}
      @todo = false
    end

    # Prints the checklist; true when nothing is left undone (✗).
    def run(number)
      @n = number
      @ep = EpisodeFile.find(@root, number) or raise ArgumentError, "no post for episode #{number} in _posts/"
      @release = Time.parse(@ep.date_string)
      @video = @ep["youtube_id"] && @youtube.call(@ep["youtube_id"])

      section("YouTube")
      youtube_visibility
      youtube_description
      youtube_chapters
      item(:unknown, "Custom thumbnail", "YouTube doesn't say if it's custom; check in Studio: #{studio_url}")
      section("Buzzsprout")
      buzzsprout_audio
      buzzsprout_chapters
      section("Website")
      website_post
      website_pushed
      section("Release (#{slot_name})")
      release_time
      buzzsprout_scheduled
      youtube_link
      youtube_scheduled
      !@todo
    end

    private

    def section(name) = @out.puts("\n#{name}")

    def item(status, label, detail = nil)
      @todo ||= status == :todo
      @out.puts("  #{MARKS.fetch(status)} #{label}#{detail ? ": #{detail}" : ''}")
    end

    def studio_url = "https://studio.youtube.com/video/#{@ep['youtube_id']}/edit"
    def episode_url = "#{@config['url']}/episodes/episode-#{@n}/"
    def private_video = "can't read the video: it's Private (expected once it's scheduled in Studio)"

    # --- YouTube ---

    def youtube_visibility
      label = "Unlisted on YouTube"
      return item(:todo, label, "no youtube_id in the post") unless @ep["youtube_id"]
      return item(:unknown, label, "Private; fine if it's scheduled in Studio, otherwise set it to Unlisted") unless @video

      item(:ok, label, @video["availability"])
    end

    def youtube_description
      label = "YouTube description"
      return item(:unknown, label, private_video) unless @video

      text = @video["description"].to_s.strip
      return item(:todo, label, "empty; paste Descript's description (with chapters) in Studio: #{studio_url}") if text.empty?

      item(:ok, label, "#{text.lines.size} lines")
    end

    def youtube_chapters
      label = "Chapters in the YouTube description"
      return item(:unknown, label, private_video) unless @video

      starts = Array(@video["chapters"]).map { |c| c["start_time"].to_f }
      problem = if starts.size < 3 then "#{starts.size} found; YouTube needs at least 3"
                elsif starts.first.positive? then "the first must be at 0:00"
                elsif starts.each_cons(2).any? { |a, b| b - a < 10 } then "chapters must be at least 10 s apart"
                end
      return item(:todo, label, "#{problem} (#{studio_url})") if problem

      local = Array(@ep["chapters"]).size
      item(:ok, label, "#{starts.size}#{local == starts.size ? '' : " (the post has #{local}: re-run `bin/episode new` or fix by hand)"}")
    end

    def youtube_link
      label = "Website link in the YouTube description"
      return item(:unknown, label, private_video) unless @video
      return item(:ok, label) if @video["description"].to_s.include?(episode_url)

      item(:todo, label, "`bin/episode sync #{@n}` copies the full description; paste it in Studio: #{studio_url}")
    end

    def youtube_scheduled
      label = "YouTube scheduled"
      return item(:unknown, label, "the video is Private; confirm in Studio it's scheduled for #{local_release}") unless @video
      return item(:ok, label, "public") if @video["availability"] == "public"

      item(:todo, label, "still #{@video['availability']}; schedule it in Studio for #{local_release}: #{studio_url}")
    end

    # --- Buzzsprout ---

    def remote
      return @remote if defined?(@remote)

      @remote = if !@ep["buzzsprout_id"]
                  @bz_error = "not linked; run `bin/episode link #{@n}` after exporting from Descript"
                  nil
                else
                  bz = @buzzsprout.respond_to?(:call) ? @buzzsprout.call : @buzzsprout
                  @remote_chapters = Array(bz.chapters(@ep["buzzsprout_id"])) if (ep = bz.episode(@ep["buzzsprout_id"]))
                  ep
                end
    rescue StandardError => e # no token, network: report, don't stop the checklist
      @bz_error = e.message
      @remote = nil
    end

    def bz_unknown(label) = item(@ep["buzzsprout_id"] ? :unknown : :todo, label, @bz_error)

    def buzzsprout_audio
      label = "Audio on Buzzsprout"
      return bz_unknown(label) unless remote

      length = remote["duration"].to_i
      return item(:todo, label, "no audio yet (export the audio-only duplicate from Descript)") if remote["audio_url"].to_s.empty? || length.zero?

      video = @video && @video["duration"].to_i
      if video&.positive? && (length - video).abs > LENGTH_SLACK
        return item(:todo, label, "#{Transcript.clock(length)} long but the video is #{Transcript.clock(video)}; wrong file?")
      end

      item(:ok, label, Transcript.clock(length))
    end

    def buzzsprout_chapters
      label = "Chapters on Buzzsprout"
      return bz_unknown(label) unless remote

      wanted = Array(@ep["chapters"])
      have = @remote_chapters.map { |c| [c["title"], seconds(c["start_time"])] }
      want = wanted.map { |c| [c["title"], seconds(c["t"])] }
      return item(:ok, label, wanted.size.to_s) if have == want && want.any?

      item(:todo, label, "#{have.size} of #{want.size} match the post; paste the chapter timeline, or `bin/episode sync #{@n}`")
    end

    def buzzsprout_scheduled
      label = "Buzzsprout scheduled"
      return bz_unknown(label) unless remote
      return item(:todo, label, "still private; `bin/episode publish #{@n}` schedules it") if remote["private"]

      at = Time.parse(remote["published_at"].to_s)
      return item(:ok, label, local_release) if at == @release

      item(:todo, label, "set for #{at.utc.iso8601}, not the post's #{@release.utc.iso8601}; `bin/episode publish #{@n}`")
    end

    # --- Website ---

    def website_post
      label = "Website post"
      missing = []
      missing << "TODOs left" if File.read(@ep.path).include?("TODO")
      { "transcript" => "_data/transcripts/episode-#{@n}.json", "thumbnail" => "assets/images/episodes/episode-#{@n}.jpg",
        "share card" => "assets/images/og/episode-#{@n}.png" }.each do |name, path|
        missing << "no #{name} (#{path})" unless File.exist?(File.join(@root, path))
      end
      missing.empty? ? item(:ok, label, File.basename(@ep.path)) : item(:todo, label, missing.join(", "))
    end

    def website_pushed
      label = "Website post pushed"
      rel = @ep.path.delete_prefix("#{@root}/")
      _, tracked = @git.call("ls-files", "--error-unmatch", rel)
      return item(:todo, label, "not committed") unless tracked

      dirty, = @git.call("status", "--porcelain", "--", rel)
      return item(:todo, label, "uncommitted changes") unless dirty.to_s.strip.empty?

      _, pushed = @git.call("diff", "--quiet", "origin/main", "--", rel)
      pushed ? item(:ok, label) : item(:todo, label, "not on origin/main yet; `git push` before #{local_release}")
    end

    # --- Release slot ---

    def slot = @config["release"] || {}
    def slot_name = "#{slot['weekday']} #{slot['time']} #{slot['zone']}"

    def release_time
      label = "Release time"
      if slot.empty? || in_zone(@release, "%A %H:%M") == "#{slot['weekday']} #{slot['time']}"
        item(:ok, label, local_release)
      else
        item(:todo, label, "the post says #{local_release}, not #{slot_name}; fix `date:` (and the filename)")
      end
    end

    def local_release = "#{in_zone(@release, '%a %b %-d %H:%M')} #{slot['zone'] || 'UTC'} (#{@release.utc.strftime('%H:%M')} UTC)"

    # Formats time in the slot's zone (no tzinfo in the bundle: a fresh Time
    # made while TZ is set picks up that zone's offset for that date).
    def in_zone(time, format)
      return time.utc.strftime(format) unless slot["zone"]

      old = ENV["TZ"]
      ENV["TZ"] = slot["zone"]
      Time.at(time.to_i).strftime(format)
    ensure
      ENV["TZ"] = old if slot["zone"]
    end

    def seconds(t)
      t.to_s.split(":").map(&:to_i).reduce(0) { |acc, part| acc * 60 + part }
    end
  end
end
