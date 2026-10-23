# frozen_string_literal: true

require "test_helper"

# Phase 1: existing pages move onto the card/chip/button components.
class PagesRestyleTest < SiteTest
  EPISODES = [3, 2, 1].freeze

  def assert_episode_cards(doc)
    cards = doc.css("article.card.episode-card")
    assert_equal EPISODES.size, cards.size, "one card per episode"
    cards.zip(EPISODES).each do |card, n|
      assert_equal "Episode #{n}", card.at_css(".chip")&.text&.strip
      link = card.at_css("a.card__link")
      assert link, "card #{n} has a whole-card link"
      assert_equal "/episodes/episode-#{n}/", link["href"]
      assert card.at_css(".card__title"), "card #{n} has a title"
    end
  end

  def test_homepage_lists_episodes_as_cards
    assert_episode_cards(page("/"))
  end

  def test_episodes_page_lists_episodes_as_cards
    assert_episode_cards(page("/episodes/"))
  end

  def test_homepage_hero_has_play_latest_and_all_episodes_buttons
    doc = page("/")
    primary = doc.at_css(".hero a.btn.btn--primary")
    assert primary, "Play the latest button"
    assert_equal "/episodes/episode-3/", primary["href"]
    assert_match(/latest/i, primary.text)
    assert doc.at_css('.hero a.btn.btn--ghost[href="/episodes/"]'), "All episodes button"
  end

  def test_episode_page_header_has_episode_chip
    assert_equal "Episode 3", page("/episodes/episode-3/").at_css(".episode-header .chip")&.text&.strip
  end

  def test_chapter_times_use_timestamp_style
    times = page("/episodes/episode-3/").css(".chapters .timestamp")
    assert_operator times.size, :>, 10
  end

  # Regression: <body> used to get the bare layout name ("episode") as its
  # class, so component rules like .episode { max-width } squeezed the page.
  def test_body_class_is_namespaced_and_cannot_collide_with_components
    { "/" => "layout-home", "/episodes/episode-3/" => "layout-episode", "/about/" => "layout-page" }.each do |path, cls|
      body = page(path).at_css("body")["class"].to_s.split
      assert_equal [cls], body, "body class on #{path}"
    end
  end

  def test_about_hosts_are_cards
    assert_equal 2, page("/about/").css("figure.host.card").size
  end

  def test_listen_links_are_chips
    links = page("/about/").css(".site-footer .listen-links a.chip")
    assert_includes links.map(&:text), "Spotify"
  end
end
