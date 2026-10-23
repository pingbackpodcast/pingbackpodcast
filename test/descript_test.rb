# frozen_string_literal: true

require "minitest/autorun"
require "json"
require_relative "buzzsprout_test" # FakeHttp
require_relative "../lib/pingback/descript"

# Phase 6: Descript API client (https://descriptapi.com/v1), no network.
class DescriptTest < Minitest::Test
  PROJECT = "9f36ee32-5a2c-47e7-b1a3-94991d3e3ddb"
  URL = "https://web.descript.com/#{PROJECT}/39677"

  def client(http) = Pingback::Descript.new(token: "dtok", http: http, sleeper: ->(_) {})

  def test_parses_project_links
    assert_equal({ project_id: PROJECT, composition_id: "39677" }, Pingback::Descript.parse(URL))
    assert_equal({ project_id: PROJECT, composition_id: nil }, Pingback::Descript.parse(PROJECT))
    assert_raises(Pingback::Descript::Error) { Pingback::Descript.parse("https://example.com/nope") }
  end

  def test_publishes_audio_and_waits_for_the_download_url
    http = FakeHttp.new([201, { "job_id" => "job1" }],
                        [200, { "job_state" => "running" }],
                        [200, { "job_state" => "stopped", "result" => { "status" => "success", "download_url" => "https://dl/a.mp3",
                                                                         "media_type" => "Audio" } }])
    url = client(http).publish_audio(URL)
    assert_equal "https://dl/a.mp3", url
    publish = http.requests.first
    assert_equal [:post, "https://descriptapi.com/v1/jobs/publish"], [publish[:method], publish[:url]]
    assert_equal "Bearer dtok", publish[:headers]["Authorization"]
    assert_equal({ "project_id" => PROJECT, "composition_id" => "39677", "media_type" => "Audio", "access_level" => "unlisted" },
                 JSON.parse(publish[:body]))
    assert_equal ["https://descriptapi.com/v1/jobs/job1"] * 2, http.requests.drop(1).map { |r| r[:url] }
  end

  def test_failed_job_raises_its_message
    http = FakeHttp.new([201, { "job_id" => "j" }], [200, { "job_state" => "stopped", "result" => { "status" => "error", "error_message" => "No media" } }])
    error = assert_raises(Pingback::Descript::Error) { client(http).publish_audio(URL) }
    assert_match(/No media/, error.message)
  end

  def test_out_of_credits_is_explained
    http = FakeHttp.new([402, { "error" => "payment_required", "message" => "Out of media minutes" }])
    error = assert_raises(Pingback::Descript::Error) { client(http).publish_audio(URL) }
    assert_match(/media minutes or AI credits/, error.message)
  end

  def test_gives_up_after_the_timeout
    http = FakeHttp.new([201, { "job_id" => "j" }], *Array.new(5) { [200, { "job_state" => "running" }] })
    d = Pingback::Descript.new(token: "t", http: http, sleeper: ->(_) {}, poll_seconds: 1, timeout_seconds: 3)
    assert_raises(Pingback::Descript::Error) { d.publish_audio(URL) }
  end

  def test_exports_the_transcript_with_speakers_markers_and_timecodes
    http = FakeHttp.new([200, "Joel: Hi.\n"])
    assert_equal "Joel: Hi.\n", client(http).export_transcript(URL)
    body = JSON.parse(http.requests.first[:body])
    assert_equal "https://descriptapi.com/v1/export/transcript", http.requests.first[:url]
    assert_equal({ "project_id" => PROJECT, "composition_id" => "39677", "format" => "txt",
                   "include_speaker_labels" => "changes", "include_markers" => true,
                   "timecodes" => { "on_speakers" => true, "on_markers" => true } }, body)
  end
end
