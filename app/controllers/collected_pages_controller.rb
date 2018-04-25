class CollectedPagesController < ApplicationController
  layout "application"

  def index
    if params[:q]
      @results = CollectedPage.find_pages(params[:q], params[:collection_id])
    else
      @collection = Collection.find(params[:collection_id])
    end
  end

  def show
    @collected_page = CollectedPage.find(params[:id])
    respond_to do |fmt|
      fmt.js {}
    end
  end

  def new
    redirect_to new_user_session_path unless current_user
    @collected_page = CollectedPage.new(new_page_params)
    @page = @collected_page.page
    @wants_icon = ! @collected_page.media.empty?
    @collection = Collection.new(collected_pages: [@collected_page])
    @bad_collection_ids = CollectedPage.where(page_id: @page.id).
      pluck(:collection_id)
    respond_to do |fmt|
      fmt.html {}
      fmt.js {}
    end
  end

  def edit
    @collected_page = CollectedPage.find(params[:id])
    respond_to do |fmt|
      fmt.js {}
    end
  end

  def update
    @collected_page = CollectedPage.find(params[:id])
    @collected_page.update_attributes(collected_page_params)
    respond_to do |fmt|
      fmt.js {}
    end
  end

  def create
    @collected_page = CollectedPage.find_or_initialize_by(existing_collected_page_params)
    is_new_page = @collected_page.new_record?
    has_media = params["collected_page"].has_key?("collected_pages_media_attributes") &&
      params["collected_page"]["collected_pages_media_attributes"].has_key?("0")
    @media_exists =
      if has_media
        if @collected_page
          CollectedPagesMedium.where(
            collected_page_id: @collected_page.id,
            medium_id: params["collected_page"]["collected_pages_media_attributes"]["0"]["medium_id"]).count > 0
        end
      end
    if @media_exists
      respond_to do |fmt|
        fmt.html do
          flash[:notice] = I18n.t(:collected_page_already_in_collection).html_safe
          return redirect_to page_media_path(@collected_page.page)
        end
        fmt.js { }
      end
    elsif @collected_page.update(collected_page_params)
      if is_new_page
        Collecting.create(user: current_user, action: "add",
          collection: @collected_page.collection, page: @collected_page.page)
      end
      if has_media
        Collecting.create(user: current_user, action: "add",
          page: @collected_page.page, collection: @collected_page.collection,
          content: @collected_page.collected_pages_media.first.medium)
      end
      respond_to do |fmt|
        fmt.html do
          flash[:notice] = I18n.t(:collected_page_added_to_collection,
            name: @collected_page.collection.name,
            page: @collected_page.page.name,
            link: collection_path(@collected_page.collection)).html_safe

          target = has_media ? page_media_path(@collected_page.page) : @collected_page.page
          redirect_to target
        end
        fmt.js { }
      end
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "new"
    end
  end

  def destroy
    @collected_page = CollectedPage.find(params[:id])
    authorize @collected_page.collection
    page = @collected_page.page
    if @collected_page.destroy
      Collecting.create(user: current_user, collection: @collected_page.collection,
        action: "remove", page: page)
      flash[:notice] = I18n.t("collected_pages.destroyed_flash", name: @collected_page.page.name)
    end
    redirect_to @collected_page.collection
  end

private

  def collected_page_params
    params.require(:collected_page).permit(:collection_id, :page_id, :annotation, collected_pages_media_attributes: [:medium_id])
  end

  def existing_collected_page_params
    params.require(:collected_page).permit(:collection_id, :page_id)
  end

  def new_page_params
    params.permit(:page_id, medium_ids: [])
  end
end
