# frozen_string_literal: true

require "test_helper"

# Only the website goes in the build: tooling, tests and docs stay private.
class BuildOutputTest < SiteTest
  PRIVATE = %w[bin lib test docs _plugins .githooks .claude CLAUDE.md Gemfile].freeze

  def test_tooling_is_not_published
    PRIVATE.each do |name|
      refute File.exist?(File.join(SiteBuild.dir, name)), "#{name} must not be in the built site"
    end
  end
end
