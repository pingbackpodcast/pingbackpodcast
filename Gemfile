# frozen_string_literal: true

source "https://rubygems.org"

gem "jekyll", "~> 4.4.1"

# Minima 3 is unreleased on RubyGems; pinned to a known-good commit on master.
# Bump the ref deliberately when upstream changes are worth taking.
gem "minima", git: "https://github.com/jekyll/minima", ref: "4de322363f"

group :jekyll_plugins do
  gem "jekyll-seo-tag", "~> 2.8"
  gem "jekyll-sitemap", "~> 1.4"
end

# Site tests (bin/test): build once, assert on the generated HTML and CSS.
group :test do
  gem "minitest", "~> 5.25"
  gem "nokogiri", "~> 1.18"
end
