# frozen_string_literal: true

require "json"
require_relative "http"

module Pingback
  # Buzzsprout API client (https://github.com/buzzsprout/buzzsprout-api).
  class Buzzsprout
    class Error < StandardError; end

    BASE = "https://www.buzzsprout.com/api"
    USER_AGENT = "PingbackPodcastSite/1.0 (+https://pingbackpodcast.com)"
    TYPES = { ".mp3" => "audio/mpeg", ".m4a" => "audio/mp4", ".wav" => "audio/wav", ".mp4" => "video/mp4" }.freeze

    def initialize(podcast_id:, token:, http: Http)
      @podcast_id, @token, @http = podcast_id, token, http
    end

    def episodes = get("episodes")
    def episode(id) = get("episodes/#{id}")
    def create_episode(attrs) = send_json(:post, "episodes", attrs)
    def update_episode(id, attrs) = send_json(:patch, "episodes/#{id}", attrs)
    def chapters(id) = get("episodes/#{id}/chapters")
    def high_fidelity_transcript(id) = get("episodes/#{id}/high_fidelity_transcript")
    def replace_high_fidelity_transcript(id, segments) = send_json(:put, "episodes/#{id}/high_fidelity_transcript", segments)

    # chapters: front matter style [{ "t" => "m:ss" | "h:mm:ss", "title" => ... }]
    def replace_chapters(id, chapters)
      list = chapters.map { |c| { "title" => c["title"], "start_time" => hms(c["t"]) } }
      send_json(:put, "episodes/#{id}/chapters", "chapters" => list)
    end

    # Start -> PUT bytes (no Buzzsprout auth) -> complete.
    def upload(id, path)
      type = TYPES.fetch(File.extname(path).downcase) { raise Error, "don't know the media type of #{path}" }
      started = send_json(:post, "episodes/#{id}/uploads",
                          "filename" => File.basename(path), "type" => type, "byte_size" => File.size(path))
      upload = started.fetch("upload")
      raise Error, "file needs a multipart upload; not supported yet" if upload["multipart"]

      res = @http.call(:put, upload.fetch("upload_url"), headers: { "Content-Type" => type }, body: File.binread(path))
      raise Error, "media upload failed: HTTP #{res.status}" unless (200..299).cover?(res.status)

      send_json(:post, "episodes/#{id}/uploads/#{upload.fetch('id')}/complete", nil)
    end

    private

    def url(path) = "#{BASE}/#{@podcast_id}/#{path}"

    def headers(json: false)
      h = { "Authorization" => "Token token=#{@token}", "User-Agent" => USER_AGENT, "Accept" => "application/json" }
      h["Content-Type"] = "application/json; charset=utf-8" if json
      h
    end

    def get(path) = parse(@http.call(:get, url(path), headers: headers))

    def send_json(method, path, payload)
      body = payload.nil? ? nil : JSON.generate(payload)
      parse(@http.call(method, url(path), headers: headers(json: !body.nil?), body: body))
    end

    def parse(res)
      unless (200..299).cover?(res.status)
        message = begin
          data = JSON.parse(res.body)
          data.dig("error", "message") || data.to_s
        rescue JSON::ParserError
          res.body.to_s[0, 200]
        end
        raise Error, "Buzzsprout returned #{res.status}: #{message}"
      end
      res.body.to_s.strip.empty? ? {} : JSON.parse(res.body)
    end

    def hms(t)
      parts = t.to_s.split(":").map(&:to_i)
      parts.unshift(0) while parts.size < 3
      format("%02d:%02d:%02d", *parts)
    end
  end
end
