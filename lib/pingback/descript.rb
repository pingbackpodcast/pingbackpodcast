# frozen_string_literal: true

require "json"
require_relative "http"

module Pingback
  # Descript API client (https://descriptapi.com/v1, bearer token from
  # Descript Settings -> API tokens). Used to render the finished episode's
  # audio and export its transcript.
  class Descript
    class Error < StandardError; end

    BASE = "https://descriptapi.com/v1"
    UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i

    # A Descript project link ("https://web.descript.com/<project>/<short>")
    # or a bare project id.
    def self.parse(link)
      project = link.to_s[UUID] or raise Error, "not a Descript project link or id: #{link}"
      short = link.to_s[%r{#{UUID}/([0-9a-z]{5})}i, 1]
      { project_id: project.downcase, composition_id: short }
    end

    def initialize(token:, http: Http, sleeper: ->(s) { sleep(s) }, poll_seconds: 5, timeout_seconds: 1800)
      @token, @http, @sleeper, @poll, @timeout = token, http, sleeper, poll_seconds, timeout_seconds
    end

    # Renders the composition as audio (an unlisted Descript share page) and
    # returns a time-limited download URL for the file.
    def publish_audio(link)
      target = self.class.parse(link)
      job = post("jobs/publish", target_body(target).merge("media_type" => "Audio", "access_level" => "unlisted"))
      result = wait(job.fetch("job_id"))
      result["download_url"] or raise Error, "Descript published the audio but returned no download link"
    end

    # Raw transcript text with speaker labels, markers and timecodes.
    def export_transcript(link, format: "txt")
      body = target_body(self.class.parse(link)).merge(
        "format" => format, "include_speaker_labels" => "changes", "include_markers" => true,
        "timecodes" => { "on_speakers" => true, "on_markers" => true }
      )
      res = @http.call(:post, "#{BASE}/export/transcript", headers: headers, body: JSON.generate(body))
      check!(res)
      res.body
    end

    private

    def target_body(target)
      { "project_id" => target[:project_id], "composition_id" => target[:composition_id] }.compact
    end

    def wait(job_id)
      waited = 0
      loop do
        job = get("jobs/#{job_id}")
        if %w[stopped cancelled].include?(job["job_state"])
          result = job["result"] || {}
          raise Error, "Descript job #{job_id} failed: #{result['error_message'] || job['job_state']}" unless result["status"] == "success"

          return result
        end
        raise Error, "Descript job #{job_id} still running after #{@timeout}s; check it in Descript" if waited >= @timeout

        @sleeper.call(@poll)
        waited += @poll
      end
    end

    def headers = { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json", "Accept" => "application/json" }

    def get(path) = parse_json(@http.call(:get, "#{BASE}/#{path}", headers: headers))
    def post(path, body) = parse_json(@http.call(:post, "#{BASE}/#{path}", headers: headers, body: JSON.generate(body)))

    def parse_json(res)
      check!(res)
      JSON.parse(res.body)
    end

    def check!(res)
      return if (200..299).cover?(res.status)

      detail = begin
        data = JSON.parse(res.body)
        data["message"] || data["error"] || data.to_s
      rescue JSON::ParserError
        res.body.to_s[0, 200]
      end
      hint = res.status == 402 ? " (the Descript plan is out of media minutes or AI credits)" : ""
      raise Error, "Descript returned #{res.status}: #{detail}#{hint}"
    end
  end
end
