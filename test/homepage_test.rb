# frozen_string_literal: true

require "test_helper"

# Phase 4: homepage hero, latest episode feature, thumbnails, listen tiles, footer.
class HomepageTest < SiteTest
  def home = @home ||= page("/")

  def test_hero_shows_the_cover_art_in_a_card
    art = home.at_css(".hero .hero__art.card img")
    assert art, "cover art card"
    assert_equal "/assets/images/cover.jpg", art["src"]
    assert_match(/Pingback/i, art["alt"].to_s)
  end

  def test_latest_episode_feature_card
    card = home.at_css("section.latest article.card.latest-card")
    assert card, "latest card"
    assert_equal "/assets/images/episodes/episode-3.jpg", card.at_css("img.latest-card__thumb")&.[]("src")
    assert_equal "Episode 3", card.at_css(".chip")&.text&.strip
    assert_match(/Sam Ruby on Roundhouse/, card.at_css(".card__title").text)
    assert card.at_css(".card__desc"), "summary"
    play = card.at_css('a.btn.btn--primary[href="/episodes/episode-3/"]')
    assert play, "play button"
    assert_equal "Play episode 3", play.text.strip
  end

  def test_episode_cards_have_thumbnails
    page("/episodes/").css("article.episode-card").each do |card|
      href = card.at_css("a.card__link")["href"]
      n = href[/episode-(\d+)/, 1]
      thumb = card.at_css("img.episode-card__thumb")
      assert thumb, "thumbnail on #{href}"
      assert_equal "/assets/images/episodes/episode-#{n}.jpg", thumb["src"]
      assert_equal "lazy", thumb["loading"]
    end
  end

  def test_listen_tiles_with_icons_kind_and_name
    tiles = home.css("section#listen a.listen-tile")
    assert_equal ["Apple Podcasts", "Spotify", "YouTube", "X", "RSS"], tiles.map { |t| t.at_css(".listen-tile__name").text.strip }
    assert_equal %w[Audio Audio Video Social Feed], tiles.map { |t| t.at_css(".listen-tile__kind").text.strip }
    tiles.each do |t|
      assert t.at_css("svg[aria-hidden='true']"), "icon on #{t['href']}"
      assert_equal "_blank", t["target"]
    end
  end

  def test_follow_box_sits_right_under_the_hero
    sections = home.css("main section").map { |s| s["id"] || s["class"] }
    assert_equal "hero", sections[0]
    assert_equal "listen", sections[1], "Follow the show box comes right after the hero"
  end

  def test_hero_has_no_follow_button_now_the_box_is_right_below
    refute home.at_css('.hero a[href="#listen"]')
  end

  def test_footer_has_about_explore_listen_and_hosts
    footer = home.at_css("footer.site-footer")
    about = footer.at_css(".site-footer__about").text
    assert_match(/Ruby, tech & more/, about)
    refute_match(/\.\./, about, "no doubled full stop after Jr.")
    explore = footer.css("nav[aria-label='Explore'] a").map { |a| a["href"] }
    assert_includes explore, "/episodes/"
    assert_includes explore, "/about/"
    icons = footer.css(".site-footer__listen a[aria-label]")
    assert_equal 5, icons.size
    assert icons.all? { |a| a.at_css("svg") }
    assert_equal ["https://greg.molnar.io", "https://joelgaff.com"], footer.css(".site-footer__hosts a").map { |a| a["href"] }
  end
end
