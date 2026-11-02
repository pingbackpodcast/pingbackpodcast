# frozen_string_literal: true

# Builds the site once (production mode) into a temp dir, then lets tests
# assert on the generated pages and the compiled stylesheet.

require "minitest/autorun"
require "nokogiri"
require "tmpdir"
require "open3"
require "time"
require_relative "../lib/pingback/episode_file"

module SiteBuild
  ROOT = File.expand_path("..", __dir__)

  def self.dir
    @dir ||= begin
      dir = Dir.mktmpdir("pingback-test")
      out, status = Open3.capture2e({ "JEKYLL_ENV" => "production" },
                                    "bundle", "exec", "jekyll", "build", "-q", "-s", ROOT, "-d", dir,
                                    chdir: ROOT)
      abort "Site build failed:\n#{out}" unless status.success?
      Minitest.after_run { FileUtils.remove_entry(dir) }
      dir
    end
  end
end

class SiteTest < Minitest::Test
  # Episodes in the build: future-dated posts are scheduled and left out, so
  # this list grows as each release time passes. Newest first.
  def self.released
    @released ||= Dir[File.join(SiteBuild::ROOT, "_posts/*.md")]
                  .map { |path| Pingback::EpisodeFile.new(path) }
                  .select { |ep| Time.parse(ep.date_string) <= Time.now }
                  .sort_by { |ep| -ep["episode"] }
  end

  def released = SiteTest.released
  def latest = released.first
  # Parsed HTML for a site path like "/" or "/episodes/episode-3/".
  def page(path)
    file = File.join(SiteBuild.dir, path, path.end_with?("/") ? "index.html" : "")
    assert File.file?(file), "no built page at #{path}"
    Nokogiri::HTML(File.read(file))
  end

  def css
    @css ||= File.read(File.join(SiteBuild.dir, "assets/css/style.css"))
  end

  # Declarations of every rule whose selector list includes `selector` exactly.
  def rules_for(selector)
    css.scan(/([^{}]+)\{([^{}]*)\}/).filter_map do |sels, body|
      sels = sels.sub(/\A\s*@charset[^;]*;/, "")
      body if sels.split(",").map(&:strip).include?(selector)
    end.join(";")
  end
end
