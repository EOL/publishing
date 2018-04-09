class HomePageController < ApplicationController
  before_action :no_main_container

  def index
    @main_feed =
      Rails.cache.fetch("home_pages/index/main_feed", expires_in: 10.minutes) do
        HomePageFeed.find_by_name("main") || HomePageFeed.new
      end
    @partner_feed =
      Rails.cache.fetch("home_pages/index/partner_feed", expires_in: 10.minutes) do
        HomePageFeed.find_by_name("partner") || HomePageFeed.new
      end
  end
end
