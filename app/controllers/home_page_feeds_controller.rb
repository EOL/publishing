class HomePageFeedsController < ApplicationController
  before_action :set_home_page_feed, only: [:show, :edit, :edit_items, :edit_items_form, :update, :destroy]

  # GET /home_page_feeds
  # GET /home_page_feeds.json
  def index
    @home_page_feeds = HomePageFeed.all
  end

  # GET /home_page_feeds/1
  # GET /home_page_feeds/1.json
  def show
  end

  # GET /home_page_feeds/new
  def new
    @home_page_feed = HomePageFeed.new
  end

  # GET /home_page_feeds/1/edit
  def edit
  end

  # GET /home_page_feeds/1/home_page_feed_items/edit
  def edit_items
    @home_page_feed.home_page_feed_items.build
    @home_page_feed.assign_attributes(home_page_feed_params)
  end

  def edit_items_form
    @home_page_feed.home_page_feed_items.build if params[:add_item]
    render "edit_items_form", :layout => false
  end

  # POST /home_page_feeds
  # POST /home_page_feeds.json
  def create
    @home_page_feed = HomePageFeed.new(home_page_feed_params)

    respond_to do |format|
      if @home_page_feed.save
        format.html { redirect_to @home_page_feed, notice: 'Home page feed was successfully created.' }
        format.json { render :show, status: :created, location: @home_page_feed }
      else
        format.html { render :new }
        format.json { render json: @home_page_feed.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /home_page_feeds/1
  # PATCH/PUT /home_page_feeds/1.json
  def update
    respond_to do |format|
      if @home_page_feed.update(home_page_feed_params)
        format.html { redirect_to @home_page_feed, notice: 'Home page feed was successfully updated.' }
        format.json { render :show, status: :ok, location: @home_page_feed }
      else
        format.html do 
          if params[:home_page_feed][:home_page_feed_items_attributes]
            render :edit_items
          else
            render :edit
          end
        end
        format.json { render json: @home_page_feed.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /home_page_feeds/1
  # DELETE /home_page_feeds/1.json
  def destroy
    @home_page_feed.destroy
    respond_to do |format|
      format.html { redirect_to home_page_feeds_url, notice: 'Home page feed was successfully destroyed.' }
      format.json { head :no_content }
    end
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
