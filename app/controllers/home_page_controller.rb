class HomePageController < ApplicationController
  before_action :no_main_container

  def index
    @main_feed = HomePageFeed.find_by_name("main") || HomePageFeed.new
    @partner_feed = HomePageFeed.find_by_name("partner") || HomePageFeed.new
  end
end
