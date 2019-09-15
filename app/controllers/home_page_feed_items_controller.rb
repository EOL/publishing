class HomePageFeedItemsController < ApplicationController
  before_action :require_admin
  before_action :set_home_page_feed
  before_action :set_home_page_feed_item, only: [:show, :edit, :update, :destroy]

  # GET /home_page_feeds/1/home_page_feed_items
  def index
    @home_page_feed_items = HomePageFeedItem.where(:home_page_feed => @home_page_feed)
  end

  # GET /home_page_feeds/1/home_page_feed_items/new
  def new
    @home_page_feed_item = HomePageFeedItem.new(:home_page_feed => @home_page_feed)
  end

  # GET /home_page_feeds/1/home_page_feed_items/1/edit
  def edit
  end

  # POST /home_page_feeds/1/home_page_feed_items
  def create
    @home_page_feed_item = HomePageFeedItem.new(home_page_feed_item_params)
    @home_page_feed_item.home_page_feed = @home_page_feed
    @home_page_feed_item.feed_version = @home_page_feed.draft_version

    respond_to do |format|
      if @home_page_feed_item.save
        format.html { redirect_to home_page_feed_items_path(@home_page_feed), notice: 'Item was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /home_page_feeds/1/home_page_feed_items/1
  def update
    respond_to do |format|
      if @home_page_feed_item.update(home_page_feed_item_params)
        format.html { redirect_to home_page_feed_items_path(@home_page_feed), notice: 'Home page feed item was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  # DELETE /home_page_feeds/1/home_page_feed_items/1
  def destroy
    @home_page_feed_item.destroy
    respond_to do |format|
      format.html { redirect_to home_page_feed_items_url, notice: 'Item was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    def set_home_page_feed
      @home_page_feed = HomePageFeed.find(params[:home_page_feed_id])
    end

    def set_home_page_feed_item
      @home_page_feed_item = HomePageFeedItem.find(params[:id])
    end

    def home_page_feed_item_params
      params.require(:home_page_feed_item).permit(:img_url, :link_url, :label, :desc, :page_id)
    end
end
