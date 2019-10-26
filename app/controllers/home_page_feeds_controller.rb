class HomePageFeedsController < ApplicationController
  before_action :require_admin
  before_action :set_home_page_feed, only: [:show, :edit, :edit_items, :edit_items_form, :update, :batch_update_items, :destroy, :publish, :batch_edit_items, :reset_draft, :current_draft_tsv]

  # GET /home_page_feeds
  # GET /home_page_feeds.json
  def index
    @home_page_feeds = [
      HomePageFeed.create_with(:fields => [:img_url, :link_url, :label]).find_or_create_by!(:name => "main"),
      HomePageFeed.create_with(:fields => [:img_url, :link_url, :label, :desc]).find_or_create_by!(:name => "partner"),
    ]
  end

  # GET /home_page_feeds/new
  def new
    @home_page_feed = HomePageFeed.new
  end

  def edit
    @home_page_feed = HomePageFeed.find(params[:id])
  end

  def update
    update_helper(home_page_feed_params, home_page_feeds_path, "edit")
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

  def batch_edit_items
  end

  def batch_update_items
    file = params.dig(:home_page_feed, :items_from_tsv)
    @home_page_feed.items_from_tsv = file

    if @home_page_feed.save
      flash[:notice] = "Draft created"
      redirect_to home_page_feed_items_path(home_page_feed_id: @home_page_feed.id)
    else
      render "batch_edit_items"
    end
  end

  def current_draft_tsv
    send_data @home_page_feed.cur_draft_items_csv, filename: "#{@home_page_feed.name}_feed_items.tsv"
  end

  def reset_draft
    @home_page_feed.reset_draft
    @home_page_feed.save!
    flash[:notice] = "Draft reset"
    redirect_to home_page_feed_items_path(home_page_feed: @home_page_feed)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_home_page_feed
      @home_page_feed = HomePageFeed.find((params[:id] || params[:home_page_feed_id]))
    end

    def update_helper(allowed_params, success_path, fail_template)
      if @home_page_feed.update(allowed_params)
        flash[:notice] = "Feed updated"
        redirect_to success_path
      else
        render fail_template
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def home_page_feed_params
      params.require(:home_page_feed).permit(
        :name, 
        :items_from_tsv,
        :fields => [], 
        :home_page_feed_items_attributes => [
          :img_url,
          :link_url,
          :label,
          :desc
        ]
      )
    end

    def batch_update_items_params
      params.permit(:home_page_feed).permit(:items_from_tsv)
    end
end
