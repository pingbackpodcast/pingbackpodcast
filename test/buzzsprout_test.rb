# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"
require_relative "../lib/pingback/buzzsprout"
require_relative "../lib/pingback/secrets"

# Phase 6: Buzzsprout API client + 1Password secrets (no network in tests).
class FakeHttp
  Response = Struct.new(:status, :body, :headers)
  attr_reader :requests

  def initialize(*responses) = (@responses = responses; @requests = [])

  def call(method, url, headers: {}, body: nil)
    @requests << { method: method, url: url, headers: headers, body: body }
    status, payload = @responses.shift || [200, {}]
    Response.new(status, payload.is_a?(String) ? payload : JSON.generate(payload), {})
  end
end

class BuzzsproutTest < Minitest::Test
  def client(http) = Pingback::Buzzsprout.new(podcast_id: "2443886", token: "tok", http: http)

  def test_reads_an_episode_with_token_auth
    http = FakeHttp.new([200, { "id" => 19975498, "title" => "Ep 3", "private" => false }])
    ep = client(http).episode(19975498)
    assert_equal "Ep 3", ep["title"]
    req = http.requests.first
    assert_equal [:get, "https://www.buzzsprout.com/api/2443886/episodes/19975498"], [req[:method], req[:url]]
    assert_equal "Token token=tok", req[:headers]["Authorization"]
    assert_match(/Pingback/, req[:headers]["User-Agent"])
  end

  def test_creates_a_private_episode
    http = FakeHttp.new([201, { "id" => 1 }])
    client(http).create_episode("title" => "Ep 4", "private" => true, "episode_number" => 4)
    req = http.requests.first
    assert_equal :post, req[:method]
    assert_equal({ "title" => "Ep 4", "private" => true, "episode_number" => 4 }, JSON.parse(req[:body]))
  end

  def test_updates_episode_fields
    http = FakeHttp.new([200, { "id" => 1 }])
    client(http).update_episode(1, "private" => false)
    assert_equal :patch, http.requests.first[:method]
  end

  def test_replaces_chapters
    http = FakeHttp.new([200, []])
    client(http).replace_chapters(1, [{ "t" => "0:00", "title" => "Welcome" }, { "t" => "1:02:05", "title" => "Wrap" }])
    req = http.requests.first
    assert_equal [:put, "https://www.buzzsprout.com/api/2443886/episodes/1/chapters"], [req[:method], req[:url]]
    assert_equal({ "chapters" => [{ "title" => "Welcome", "start_time" => "00:00:00" },
                                  { "title" => "Wrap", "start_time" => "01:02:05" }] }, JSON.parse(req[:body]))
  end

  def test_uploads_media_in_three_steps
    Dir.mktmpdir do |dir|
      file = File.join(dir, "episode.mp3")
      File.binwrite(file, "AUDIO")
      http = FakeHttp.new([201, { "upload" => { "id" => "up1", "multipart" => false, "upload_url" => "https://up.example/x" } }],
                          [200, ""], [200, { "id" => 1 }])
      client(http).upload(1, file)
      start, put, complete = http.requests
      assert_equal({ "filename" => "episode.mp3", "type" => "audio/mpeg", "byte_size" => 5 }, JSON.parse(start[:body]))
      assert_equal [:put, "https://up.example/x", "AUDIO"], [put[:method], put[:url], put[:body]]
      refute put[:headers].key?("Authorization"), "never send the Buzzsprout token to the upload host"
      assert_equal "https://www.buzzsprout.com/api/2443886/episodes/1/uploads/up1/complete", complete[:url]
    end
  end

  def test_api_errors_raise_with_the_message
    http = FakeHttp.new([422, { "error" => { "message" => "chapters must be an array" } }])
    error = assert_raises(Pingback::Buzzsprout::Error) { client(http).replace_chapters(1, []) }
    assert_match(/422.*chapters must be an array/, error.message)
  end
end

class SecretsTest < Minitest::Test
  def test_reads_from_1password_vault_item
    calls = []
    runner = ->(*cmd) { calls << cmd; ["s3cret\n", true] }
    assert_equal "s3cret", Pingback::Secrets.new(runner: runner, env: {}).fetch(:buzzsprout)
    assert_equal [["op", "read", "op://Pingback Podcast/Descript/Buzzsprout API token"]], calls
  end

  def test_descript_token_is_a_field_on_the_descript_login_item
    calls = []
    runner = ->(*cmd) { calls << cmd; ["dtok\n", true] }
    assert_equal "dtok", Pingback::Secrets.new(runner: runner, env: {}).fetch(:descript)
    assert_equal [["op", "read", "op://Pingback Podcast/Descript/Descript website deploy API token"]], calls
  end

  def test_environment_variable_wins
    runner = ->(*) { flunk "op should not run" }
    assert_equal "envtok", Pingback::Secrets.new(runner: runner, env: { "PINGBACK_DESCRIPT_TOKEN" => "envtok" }).fetch(:descript)
  end

  def test_explains_how_to_fix_a_failed_read
    runner = ->(*) { ["", false] }
    error = assert_raises(Pingback::Secrets::Error) { Pingback::Secrets.new(runner: runner, env: {}).fetch(:buzzsprout) }
    assert_match(/op signin/, error.message)
    assert_match(/Buzzsprout API token/, error.message)
  end
end
