# frozen_string_literal: true

require "json"
require "open3"
require "date"
require_relative "episode_file"
require_relative "transcript"

module Pingback
  # Scaffolds _posts/YYYY-MM-DD-episode-N.md from the episode's YouTube video
  # (yt-dlp works for unlisted videos too). The date is a placeholder until
  # the Buzzsprout release time is known; TODOs mark what's left to write.
  class NewEpisode
    class Error < StandardError; end

    def initialize(root:, runner: ->(*cmd) { out, st = Open3.capture2(*cmd, err: File::NULL); [out, st.success?] })
      @root, @runner = root, runner
    end

    def run(number, youtube:)
      raise Error, "episode #{number} already exists" if EpisodeFile.find(@root, number)

      out, ok = @runner.call("yt-dlp", "--skip-download", "--dump-single-json", "--no-warnings", youtube)
      raise Error, "yt-dlp couldn't read #{youtube}: is the video Unlisted, not Private (YouTube hides private videos), and is the link right?" unless ok

      info = JSON.parse(out)
      date = Date.strptime(info.fetch("upload_date"), "%Y%m%d")
      path = File.join(@root, "_posts", "#{date.iso8601}-episode-#{number}.md")
      File.write(path, render(number, info, date))
      path
    end

    private

    def render(number, info, date)
      chapters = Array(info["chapters"]).map do |c|
        %(  - { t: "#{Transcript.clock(c['start_time'])}", title: #{c['title'].to_s.strip.to_json} })
      end
      <<~MD
        ---
        title: "TODO: episode title (YouTube: #{info['title'].to_s.gsub('"', "'")})"
        date: #{date.iso8601} 23:00:00 -0700  # TODO: Buzzsprout release time, Pacific
        episode: #{number}
        duration: "#{(info['duration'].to_f / 60).round} min"
        topics: []
        guests: []
        youtube_id: #{info.fetch('id')}
        description: "TODO: one or two sentences for cards, SEO and the share card."
        #{chapters.any? ? "chapters:\n#{chapters.join("\n")}" : 'chapters: []'}
        ---
        TODO: show notes.
      MD
    end
  end
end
