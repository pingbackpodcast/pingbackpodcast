# frozen_string_literal: true

# Builds the site once (production mode) into a temp dir, then lets tests
# assert on the generated pages and the compiled stylesheet.

require "minitest/autorun"
require "nokogiri"
require "tmpdir"
require "open3"

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
