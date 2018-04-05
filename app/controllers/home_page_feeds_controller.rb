class HomePageFeedsController < ApplicationController
  before_action :require_admin
  before_action :set_home_page_feed, only: [:show, :edit, :edit_items, :edit_items_form, :update, :destroy, :publish]

  # GET /home_page_feeds
  # GET /home_page_feeds.json
  def index
    @home_page_feeds = [
      HomePageFeed.create_with(:fields => [:img_url, :link_url, :label]).find_or_create_by!(:name => "main"),
      HomePageFeed.create_with(:fields => [:img_url, :link_url, :label]).find_or_create_by!(:name => "partner"),
    ]
  end

  # GET /home_page_feeds/new
  def new
    @home_page_feed = HomePageFeed.new
  end

  # POST /home_page_feeds
  # POST /home_page_feeds.json
  def create
    @home_page_feed = HomePageFeed.new(home_page_feed_params)

    respond_to do |format|
      if @home_page_feed.save
        format.html { redirect_to home_page_feeds_path, notice: 'Home page feed was successfully created.' }
        format.json { render :show, status: :created, location: @home_page_feed }
      else
        format.html { render :new }
        format.json { render json: @home_page_feed.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /home_page_feeds/1/publish
  def publish
    @home_page_feed.publish!
    redirect_to home_page_feed_items_url(@home_page_feed)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_home_page_feed
      @home_page_feed = HomePageFeed.find((params[:id] || params[:home_page_feed_id]))
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def home_page_feed_params
      params.require(:home_page_feed).permit(
        :name, 
        :fields => [], 
        :home_page_feed_items_attributes => [
          :img_url,
          :link_url,
          :label,
          :desc
        ]
      )
    end
end
