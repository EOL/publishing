class HomePageFeedItemsController < ApplicationController
  before_action :set_home_page_feed
  before_action :set_home_page_feed_item, only: [:show, :edit, :update, :destroy]

  # GET /home_page_feed_items
  # GET /home_page_feed_items.json
  def index
    @home_page_feed_items = HomePageFeedItem.where(:home_page_feed => @home_page_feed)
  end

  # GET /home_page_feed_items/1
  # GET /home_page_feed_items/1.json
  def show
  end

  # GET /home_page_feed_items/new
  def new
    @home_page_feed_item = HomePageFeedItem.new(:home_page_feed => @home_page_feed)
  end

  # GET /home_page_feed_items/1/edit
  def edit
  end

  # POST /home_page_feed_items
  # POST /home_page_feed_items.json
  def create
    @home_page_feed_item = HomePageFeedItem.new(home_page_feed_item_params)
    @home_page_feed_item.home_page_feed = @home_page_feed

    respond_to do |format|
      if @home_page_feed_item.save
        format.html { redirect_to home_page_feed_item_path(@home_page_feed, @home_page_feed_item), notice: 'Home page feed item was successfully created.' }
        format.json { render :show, status: :created, location: @home_page_feed_item }
      else
        format.html { render :new }
        format.json { render json: @home_page_feed_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /home_page_feed_items/1
  # PATCH/PUT /home_page_feed_items/1.json
  def update
    respond_to do |format|
      if @home_page_feed_item.update(home_page_feed_item_params)
        format.html { redirect_to @home_page_feed_item, notice: 'Home page feed item was successfully updated.' }
        format.json { render :show, status: :ok, location: @home_page_feed_item }
      else
        format.html { render :edit }
        format.json { render json: @home_page_feed_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /home_page_feed_items/1
  # DELETE /home_page_feed_items/1.json
  def destroy
    @home_page_feed_item.destroy
    respond_to do |format|
      format.html { redirect_to home_page_feed_items_url, notice: 'Home page feed item was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    def set_home_page_feed
      @home_page_feed = HomePageFeed.find(params[:home_page_feed_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_home_page_feed_item
      @home_page_feed_item = HomePageFeedItem.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def home_page_feed_item_params
      params.require(:home_page_feed_item).permit(:img_url, :link_url, :label, :desc, :home_page_feed_id)
    end
end
