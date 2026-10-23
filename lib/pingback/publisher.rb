# frozen_string_literal: true

require "yaml"
require "time"
require "kramdown"
require_relative "episode_file"
require_relative "buzzsprout"
require_relative "transcript"
require_relative "youtube_text"

module Pingback
  # bin/episode sync / publish / status: the repo's episode file is the source
  # of truth; Buzzsprout and the YouTube description are filled from it.
  class Publisher
    class Error < StandardError; end

    SYNC_FIELDS = %w[title description tags episode_number].freeze

    # buzzsprout: a client, or a proc that builds one (called only when an
    # API call is actually about to happen).
    def initialize(root:, buzzsprout:, clipboard: nil, out: $stdout)
      @root, @buzzsprout, @clipboard, @out = root, buzzsprout, clipboard, out
      @config = YAML.safe_load_file(File.join(root, "_config.yml")) || {}
    end

    # Push title, show notes, tags, number and chapters to Buzzsprout (never
    # changes private/published), then put the YouTube description on the
    # clipboard. dry_run: only read and report what would change.
    def sync(number, dry_run: false)
      ep = load(number)
      id = ep["buzzsprout_id"]
      remote = bz.episode(id)
      wanted = {
        "title" => ep["title"],
        "description" => description_html(ep),
        "tags" => topic_names(ep).join(","),
        "episode_number" => ep["episode"]
      }
      changes = SYNC_FIELDS.reject { |k| remote[k] == wanted[k] }
      chapters = Array(ep["chapters"])

      if dry_run
        remote_chapters = Array(bz.chapters(id))
        report_dry_run(remote, wanted, changes, id, chapters, remote_chapters)
        return
      end

      bz.update_episode(id, wanted.slice(*changes)) if changes.any?
      bz.replace_chapters(id, chapters) if chapters.any?
      say "Buzzsprout: #{changes.any? ? "updated #{changes.join(', ')}" : 'details already in sync'}" \
          "#{chapters.any? ? ", #{chapters.size} chapters" : ''}"
      youtube(ep)
    end

    def publish(number, at: nil)
      ep = load(number)
      when_at = Time.parse(at || ep.date_string).iso8601
      result = bz.update_episode(ep["buzzsprout_id"], "private" => false, "published_at" => when_at)
      future = Time.parse(when_at) > Time.now
      say "Buzzsprout: #{future ? "scheduled for #{when_at}" : "published (#{when_at})"}" \
          "#{result['private'] == false ? '' : ' — check the dashboard'}"
      say "YouTube: set the video to Public in Studio: #{studio_url(ep)}" if ep["youtube_id"]
    end

    # Just the YouTube description (works before Buzzsprout has the episode).
    def youtube_text(number)
      ep = EpisodeFile.find(@root, number) or raise Error, "no post for episode #{number} in _posts/"
      raise Error, "episode #{number} has no youtube_id" unless ep["youtube_id"]

      youtube(ep)
    end

    def status(number)
      ep = load(number)
      remote = bz.episode(ep["buzzsprout_id"])
      remote_chapters = Array(bz.chapters(ep["buzzsprout_id"]))
      state = remote["private"] ? "private" : (Time.parse(remote["published_at"].to_s) > Time.now ? "scheduled" : "public")
      say "Episode #{number}: #{ep['title']}"
      say "  Buzzsprout: #{state}, published_at #{remote['published_at']}, " \
          "length #{Transcript.clock(remote['duration'].to_i)}"
      say "  title: #{remote['title'] == ep['title'] ? 'matches' : "differs (#{remote['title'].inspect})"}"
      say "  chapters: #{remote_chapters.size} on Buzzsprout, #{Array(ep['chapters']).size} in the repo"
    end

    private

    def bz = (@bz ||= @buzzsprout.respond_to?(:call) ? @buzzsprout.call : @buzzsprout)

    def load(number)
      ep = EpisodeFile.find(@root, number) or raise Error, "no post for episode #{number} in _posts/"
      raise Error, "episode #{number} has no buzzsprout_id yet (export the audio from Descript to Buzzsprout, then add it)" unless ep["buzzsprout_id"]

      ep
    end

    def say(line) = @out.puts(line)

    def episode_url(ep) = "#{@config['url']}/episodes/episode-#{ep['episode']}/"
    def studio_url(ep) = "https://studio.youtube.com/video/#{ep['youtube_id']}/edit"

    def description_html(ep)
      notes = Kramdown::Document.new(ep.body.strip).to_html.strip
      link = %(<p>Chapters, best moments and the full transcript: <a href="#{episode_url(ep)}">#{episode_url(ep)}</a></p>)
      "#{notes}\n#{link}"
    end

    def topic_names(ep)
      topics = YAML.safe_load_file(File.join(@root, "_data/topics.yml")) || []
      Array(ep["topics"]).filter_map { |slug| topics.find { |t| t["slug"] == slug }&.fetch("name") }
    end

    def chapters_differ?(remote_chapters, chapters)
      remote_chapters.map { |c| [c["title"], c["start_time"]] } != chapters.map { |c| [c["title"], hms(c["t"])] }
    end

    def report_dry_run(remote, wanted, changes, id, chapters, remote_chapters)
      chapters_changed = chapters_differ?(remote_chapters, chapters)
      if changes.empty? && !chapters_changed
        say "Buzzsprout episode #{id} is already in sync."
        return
      end
      say "Dry run: would update Buzzsprout episode #{id}:"
      changes.each do |k|
        shown = k == "description" ? "(#{remote[k].to_s.size} chars) -> (#{wanted[k].size} chars)" : "#{remote[k].inspect} -> #{wanted[k].inspect}"
        say "  #{k}: #{shown}"
      end
      say "  chapters: #{remote_chapters.size} -> #{chapters.size}" if chapters_changed
    end

    def youtube(ep)
      return unless ep["youtube_id"]

      platforms = YAML.safe_load_file(File.join(@root, "_data/platforms.yml")) || []
      text = YoutubeText.build(body: ep.body, chapters: Array(ep["chapters"]), url: episode_url(ep), platforms: platforms)
      copied = @clipboard&.call(text)
      where = copied == :printed ? "printed above" : "copied to the clipboard"
      say "YouTube: description #{where}. Paste it in Studio and Save: #{studio_url(ep)}"
    end

    def hms(t)
      parts = t.to_s.split(":").map(&:to_i)
      parts.unshift(0) while parts.size < 3
      format("%02d:%02d:%02d", *parts)
    end
  end
end
